/***************************************************************************
 *                                  _   _ ____  _
 *  Project                     ___| | | |  _ \| |
 *                             / __| | | | |_) | |
 *                            | (__| |_| |  _ <| |___
 *                             \___|\___/|_| \_\_____|
 *
 * Copyright (C) 1998 - 2019, Daniel Stenberg, <daniel@haxx.se>, et al.
 *
 * This software is licensed as described in the file COPYING, which
 * you should have received as part of this distribution. The terms
 * are also available at https://curl.haxx.se/docs/copyright.html.
 *
 * You may opt to use, copy, modify, merge, publish, distribute and/or sell
 * copies of the Software, and permit persons to whom the Software is
 * furnished to do so, under the terms of the COPYING file.
 *
 * This software is distributed on an "AS IS" basis, WITHOUT WARRANTY OF ANY
 * KIND, either express or implied.
 *
 ***************************************************************************/ 
/* <DESC>
 * Multiplexed HTTP/2 downloads over a single connection
 * </DESC>
 */ 
#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <string.h>

#include <sys/syscall.h>

/* somewhat unix-specific */ 
#include <sys/time.h>
#include <unistd.h>
#include <getopt.h>

/* curl stuff */ 
#include <curl/curl.h>
 
#ifndef CURLPIPE_MULTIPLEX
/* This little trick will just make sure that we don't enable pipelining for
   libcurls old enough to not have this symbol. It is _not_ defined to zero in
   a recent libcurl header. */ 
#define CURLPIPE_MULTIPLEX 0
#endif
#include <execinfo.h>  
#include <signal.h>  
 
static long long current_us(void) {
    struct timeval tv_date;

    gettimeofday(&tv_date, NULL);
    return ((long long)tv_date.tv_sec * 1000000 + (long long)tv_date.tv_usec);
}

void backtracedump(int signo)  
{  
    void *buffer[30] = {0};  
    size_t size;  
    char **strings = NULL;  
    size_t i = 0;  
                      
    size = backtrace(buffer, 30);  
    fprintf(stdout, "Obtained %zd stack frames.nm\n", size);  
    strings = backtrace_symbols(buffer, size);  
    if (strings == NULL) {  
        perror("backtrace_symbols.");  
        exit(EXIT_FAILURE);  
    }  
                                          
    for (i = 0; i < size; i++) {  
        fprintf(stdout, "%s\n", strings[i]);  
    }  
    free(strings);  
    strings = NULL;  
    exit(0);  
} 

struct transfers_info {
  int total_request;
  int cur_finish;
  const char *ext;
  char speed_info[10];
  long long last_ts;
  double bytes;
};

struct transfer {
  CURL *easy;
  unsigned int num;
  FILE *out;
  FILE *header;
  char url[100];
  char data_file[100];
  char header_file[100];
  int finish;
  int header_writed;
  int data_writed;
  int have_cookies;
  double dltotal;
  struct transfers_info *info;
};
 
#define NUM_HANDLES 450

static
size_t header_callback(char *ptr, size_t size, size_t nmemb, void *userdata) {
    struct transfer *t = (struct transfer *)userdata;
    size_t bytes;
    if(t->header_writed == 0)
        t->header = fopen(t->header_file, "wb+");
    else
        t->header = fopen(t->header_file, "ab+");

    if (t->header == NULL) {
        printf("open %s failed(%s)\n", t->header_file, strerror(errno));
        exit(-1);
    }

    t->header_writed = 1;
    bytes = fwrite(ptr, size, nmemb, t->header);
    fclose(t->header);
    t->header = NULL;
    return bytes;
}

static
size_t data_callback(char *ptr, size_t size, size_t nmemb, void *userdata) {
    struct transfer *t = (struct transfer *)userdata;
    size_t bytes;
    if(t->data_writed == 0 && t->have_cookies == 0)
        t->out = fopen(t->data_file, "wb+");
    else
        t->out = fopen(t->data_file, "ab+");

    if (t->out == NULL) {
        printf("open %s failed(%s)\n", t->data_file, strerror(errno));
        exit(-1);
    }

    t->data_writed = 1;
    t->info->bytes += size * nmemb;
    bytes = fwrite(ptr, size, nmemb, t->out);
    fclose(t->out);
    t->out = NULL;
    return bytes;
}
static
int progress_callback(void *clientp, double dltotal, double dlnow, double ultotal, double ulnow)
{
    struct transfer *t = (struct transfer *)clientp;
    
    if(dltotal == 0) return 0;
    if(t->finish == 1) return 0;
    
    long long now = current_us();
    float time_pass = (now - t->info->last_ts) / (1000 * 1000 * 1.0);
    if (time_pass > 1.0) {
        float speed = (float)t->info->bytes / time_pass;
        if (t->info->bytes > 1024 * 1024) {
            // MB/s
            snprintf(t->info->speed_info, sizeof(t->info->speed_info), "%.01fMB/s", speed/(1024 * 1024 * 1.0));
        } else if (t->info->bytes > 1024) {
            // KB/s
            snprintf(t->info->speed_info, sizeof(t->info->speed_info), "%dKB/s", (int)(speed/1024));
        } else {
            // B/s
            snprintf(t->info->speed_info, sizeof(t->info->speed_info), "%dB/s", (int)speed);
        }
        t->info->last_ts = now;
        t->info->bytes = 0;
    }
    
    int nPersent = (int)(100.0*dlnow/dltotal);
    
    printf("\r");
    if(t->info->ext != NULL) printf("%s", t->info->ext);
    printf("[%d/%d][%d] %s %d->%s dltotal[%03lf] dlnow[%03lf], cookies: %d",
                t->info->cur_finish + 1, t->info->total_request, nPersent,
                t->info->speed_info,
                t->num,
                t->url,
                dltotal,
                dlnow,
                t->have_cookies);
    fflush(stdout);
    if(dltotal == dlnow) {
        t->finish = 1;
        t->info->cur_finish++;
        printf("\n");
    }

    if(dltotal < 0)
    {
       printf("\n dltotal[%03lf] dlnow[%03lf] ultotal[%03lf] ulnow[%03lf]",dltotal,dlnow,ultotal,ulnow);
        int nPersent = (int)(100.0*dlnow/dltotal);
        printf("\n persent[%d]",nPersent);
    }   
    return 0;
    
}

static int check_and_get_file_cookies(const char *filename) {
    FILE *fp = NULL;
    if(access(filename, F_OK) != 0) return 0;

    fp = fopen(filename, "rb");
    if(fp == NULL) return 0;

    fseek(fp, 0, SEEK_END); //定位到文件末
    int nFileLen = ftell(fp); //文件长度

    fclose(fp);

    return nFileLen;
}

static
void dump(const char *text, int num, unsigned char *ptr, size_t size,
          char nohex)
{
  size_t i;
  size_t c;
 
  unsigned int width = 0x10;
 
  if(nohex)
    /* without the hex output, we can fit more on screen */ 
    width = 0x40;
 
  fprintf(stderr, "%d %s, %lu bytes (0x%lx)\n",
          num, text, (unsigned long)size, (unsigned long)size);
 
  return;
  for(i = 0; i<size; i += width) {
 
    fprintf(stderr, "%4.4lx: ", (unsigned long)i);
 
    if(!nohex) {
      /* hex not disabled, show it */ 
      for(c = 0; c < width; c++)
        if(i + c < size)
          fprintf(stderr, "%02x ", ptr[i + c]);
        else
          fputs("   ", stderr);
    }
 
    for(c = 0; (c < width) && (i + c < size); c++) {
      /* check for 0D0A; if found, skip past and start a new line of output */ 
      if(nohex && (i + c + 1 < size) && ptr[i + c] == 0x0D &&
         ptr[i + c + 1] == 0x0A) {
        i += (c + 2 - width);
        break;
      }
      fprintf(stderr, "%c",
              (ptr[i + c] >= 0x20) && (ptr[i + c]<0x80)?ptr[i + c]:'.');
      /* check again for 0D0A, to avoid an extra \n if it's at width */ 
      if(nohex && (i + c + 2 < size) && ptr[i + c + 1] == 0x0D &&
         ptr[i + c + 2] == 0x0A) {
        i += (c + 3 - width);
        break;
      }
    }
    fputc('\n', stderr); /* newline */ 
  }
}
 
static
int my_trace(CURL *handle, curl_infotype type,
             char *data, size_t size,
             void *userp)
{
  const char *text;
  struct transfer *t = (struct transfer *)userp;
  unsigned int num = t->num;
  (void)handle; /* prevent compiler warning */ 
  
  switch(type) {
  case CURLINFO_TEXT:
    fprintf(stderr, "== %d Info: %s", num, data);
    /* FALLTHROUGH */ 
  default: /* in case a new one is introduced to shock us */ 
    return 0;
 
  case CURLINFO_HEADER_OUT:
    text = "=> Send header";
    break;
  case CURLINFO_DATA_OUT:
    text = "=> Send data";
    break;
  case CURLINFO_SSL_DATA_OUT:
    text = "=> Send SSL data";
    break;
  case CURLINFO_HEADER_IN:
    text = "<= Recv header";
    break;
  case CURLINFO_DATA_IN:
    text = "<= Recv data";
    break;
  case CURLINFO_SSL_DATA_IN:
    text = "<= Recv SSL data";
    break;
  }
 
  dump(text, num, (unsigned char *)data, size, 1);
  return 0;
}
 
static void setup(struct transfer *t, int num, const char *url, const char *outfilename, int verbose)
{
  char headerfilename[128];
  CURL *hnd;
  memset(headerfilename, 0, 128);
  hnd = t->easy = curl_easy_init();
  
  strncpy(t->url, url, sizeof(t->url));
  t->num = num;
  t->finish = 0;
  t->header_writed = 0;
  t->data_writed = 0;
  t->dltotal = 0;

  snprintf(headerfilename, 128, "%s.header", outfilename);
/*
  t->out = fopen(outfilename, "wb");
  if (t->out == NULL) {
    printf("open %s failed(%s)\n", outfilename, strerror(errno));
    //exit(-1);
  }
  t->header = fopen(headerfilename, "wb");
  if (t->header == NULL) {
    printf("open %s failed(%s)\n", outfilename, strerror(errno));
    //exit(-1);
  }
*/
  memset(t->data_file, 0, sizeof(t->data_file));
  memset(t->header_file, 0, sizeof(t->header_file));
  strncpy(t->data_file, outfilename, sizeof(t->data_file));
  strncpy(t->header_file, headerfilename, sizeof(t->header_file));

  /* write to this file */ 
  //curl_easy_setopt(hnd, CURLOPT_WRITEDATA, t->out);
  //curl_easy_setopt(hnd, CURLOPT_HEADERDATA, t->header); //将返回的html主体数据输出到fp指向的文件
  curl_easy_setopt(hnd, CURLOPT_HEADERFUNCTION, header_callback);
  curl_easy_setopt(hnd, CURLOPT_HEADERDATA, t);

  curl_easy_setopt(hnd, CURLOPT_WRITEFUNCTION, data_callback);
  curl_easy_setopt(hnd, CURLOPT_WRITEDATA, t);
  
  printf("%d, url: %s, file %s", num, url, outfilename);

  t->have_cookies = 0;
  int cookies = check_and_get_file_cookies(outfilename);
  if(cookies > 0) {
    char range[20];
    snprintf(range, sizeof(range), "%d-", cookies);
    curl_easy_setopt(hnd, CURLOPT_RANGE, range);
    t->have_cookies = cookies;
    printf(", cookies: %d", cookies);
  }

  printf("\n");

  /* set the same URL */ 
  curl_easy_setopt(hnd, CURLOPT_URL, url);
 
  /* please be verbose */ 
  curl_easy_setopt(hnd, CURLOPT_VERBOSE, verbose);
  curl_easy_setopt(hnd, CURLOPT_DEBUGFUNCTION, my_trace);
  curl_easy_setopt(hnd, CURLOPT_DEBUGDATA, t);

  curl_easy_setopt(hnd, CURLOPT_PROGRESSFUNCTION, progress_callback); 
  curl_easy_setopt(hnd, CURLOPT_PROGRESSDATA, t);
  curl_easy_setopt(hnd, CURLOPT_NOPROGRESS, 0L);
  /* HTTP/2 please */ 
  curl_easy_setopt(hnd, CURLOPT_HTTP_VERSION, CURL_HTTP_VERSION_2_0);
 
  /* we use a self-signed test server, skip verification during debugging */ 
  curl_easy_setopt(hnd, CURLOPT_SSL_VERIFYPEER, 0L);
  curl_easy_setopt(hnd, CURLOPT_SSL_VERIFYHOST, 0L);
 
#if (CURLPIPE_MULTIPLEX > 0)
  /* wait for pipe connection to confirm */ 
  curl_easy_setopt(hnd, CURLOPT_PIPEWAIT, 1L);
#endif
}

int get_filename_from_url(const char *url, char *filename) {
    int i = 0;
    int size = strlen(url);
    for( i = size - 1; i >= 0; i--) {
        if( url[i] == '/' ) {
            i = i + 1;
            break;
        } 
    }
    strncpy(filename, url + i, strlen(url + i)); 
    return 0;
}

/*
 * Download many transfers over HTTP/2, using the same connection!
 */ 
int main(int argc, char **argv)
{
  struct transfers_info info;
  struct transfer trans[NUM_HANDLES];
  CURLM *multi_handle;
  int i;
  int still_running = 0; /* keep number of running handles */ 
  int max_transfers = NUM_HANDLES;
  int num_transfers = 0;
  const char *url_file = NULL;
  FILE *fp;
  char line[200];
  int opt = 0; 
  int verbose = 0;
  int timeout_set = 10;
  int timeout_step = 0;
  int timeout_count = 0;
  int timeout_update = 0;
  signal(SIGSEGV, backtracedump);

  info.ext = NULL;
  info.last_ts = current_us();
  info.bytes = 0;
  snprintf(info.speed_info, sizeof(info.speed_info), "0B/s");

  while((opt = getopt(argc, argv,"f:n:t:i:v")) != -1) {
    //optarg is global
    switch(opt) {
    case 'n':
        max_transfers = atoi(optarg);
        printf("The max_transfers is %d\n", max_transfers);
        break;
    case 'f':
        url_file = optarg;
        printf("The url file is %s\n", optarg);
        break;
    case 't':
        timeout_set = atoi(optarg);
        printf("The setting timeout is %d\n", timeout_set);
        break;
    case 'i':
        info.ext = optarg;
        printf("info: %s\n", info.ext);
        break;
    case 'v':
        verbose = 1;
        break;
    break;
    default:
        //非法参数处理，也可以使用case来处理，？表示无效的选项，：表示选项缺少参数
        exit(1);
    }
  }

  if(url_file == NULL) exit(-1);

  /* init a multi stack */ 
  multi_handle = curl_multi_init();
  
  fp = fopen(url_file, "r");
  if(fp == NULL) {
    printf("Open %s failed,(%s)\n", url_file, strerror(errno));
    exit(-1);
  }
  
  while(fgets(line, sizeof(line), fp)) {
    int i = 0;
    char filename[100];
    if (strncmp(line, "http", 4)) continue;
    while(i < sizeof(line)) {
        if( line[i] == 0x0a ) {
            line[i] = 0; break;
        }
        i++;
    }
    memset(filename, 0, sizeof(filename));
    get_filename_from_url(line, filename);
    setup(&trans[num_transfers], num_transfers, line, filename, verbose);
    trans[num_transfers].info = &info;


    /* add the individual transfer */ 
    curl_multi_add_handle(multi_handle, trans[num_transfers].easy);
    
    num_transfers++;
    if(num_transfers >= max_transfers) break;
  }
  fclose(fp);

  info.total_request = num_transfers;
  info.cur_finish = 0;
  curl_multi_setopt(multi_handle, CURLMOPT_PIPELINING, CURLPIPE_MULTIPLEX);
 
  /* we start some action by calling perform right away */ 
  curl_multi_perform(multi_handle, &still_running);
 
  while(still_running) {
    struct timeval timeout;
    int rc; /* select() return code */ 
    CURLMcode mc; /* curl_multi_fdset() return code */ 
 
    fd_set fdread;
    fd_set fdwrite;
    fd_set fdexcep;
    int maxfd = -1;
 
    long curl_timeo = -1;
 
    FD_ZERO(&fdread);
    FD_ZERO(&fdwrite);
    FD_ZERO(&fdexcep);
 
    /* set a suitable timeout to play around with */ 
    timeout.tv_sec = 1;
    timeout.tv_usec = 0;
 
    curl_multi_timeout(multi_handle, &curl_timeo);
    if(curl_timeo >= 0) {
      timeout.tv_sec = curl_timeo / 1000;
      if(timeout.tv_sec > 1)
        timeout.tv_sec = 1;
      else
        timeout.tv_usec = (curl_timeo % 1000) * 1000;
    }
    timeout_step = timeout.tv_sec;

    /* get file descriptors from the transfers */ 
    mc = curl_multi_fdset(multi_handle, &fdread, &fdwrite, &fdexcep, &maxfd);
 
    if(mc != CURLM_OK) {
      fprintf(stderr, "curl_multi_fdset() failed, code %d.\n", mc);
      break;
    }
 
    /* On success the value of maxfd is guaranteed to be >= -1. We call
       select(maxfd + 1, ...); specially in case of (maxfd == -1) there are
       no fds ready yet so we call select(0, ...) --or Sleep() on Windows--
       to sleep 100ms, which is the minimum suggested value in the
       curl_multi_fdset() doc. */ 
 
    if(maxfd == -1) {
#ifdef _WIN32
      Sleep(100);
      rc = 0;
#else
      /* Portable sleep for platforms other than Windows. */ 
      struct timeval wait = { 0, 100 * 1000 }; /* 100ms */ 
      rc = select(0, NULL, NULL, NULL, &wait);
#endif
    }
    else {
      /* Note that on some platforms 'timeout' may be modified by select().
         If you need access to the original value save a copy beforehand. */ 
      rc = select(maxfd + 1, &fdread, &fdwrite, &fdexcep, &timeout);
    }
 
    switch(rc) {
    case -1:
      /* select error */ 
      break;
    case 0:
      timeout_count += timeout_step;
      //printf("\nselect timeout %d(s)\n", timeout_count);
      timeout_update = 1;
    default:
      if(timeout_update == 0) timeout_count = 0;
      timeout_update = 0;
      /* timeout or readable/writable sockets */ 
      curl_multi_perform(multi_handle, &still_running);
      break;
    }
    if(timeout_count >= timeout_set) {
        printf("\nTimeout %d sec, exit!\n", timeout_count);
        break;
    }
  }
 
  for(i = 0; i < num_transfers; i++) {
    curl_multi_remove_handle(multi_handle, trans[i].easy);
    curl_easy_cleanup(trans[i].easy);
    if(trans[i].out != NULL) {
        fflush(trans[i].out);
        fclose(trans[i].out);
    }
    if(trans[i].header != NULL) fclose(trans[i].header);
  }
 
  curl_multi_cleanup(multi_handle);
 
  return 0;
}
