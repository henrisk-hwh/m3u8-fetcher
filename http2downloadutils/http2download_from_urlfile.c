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

struct transfer {
  CURL *easy;
  unsigned int num;
  FILE *out;
  FILE *header;
  char url[100];
  int finish;
};
 
#define NUM_HANDLES 450

static
int progress_callback(void *clientp, double dltotal, double dlnow, double ultotal, double ulnow)
{
    struct transfer *t = (struct transfer *)clientp;
    
    if(dltotal == 0) return 0;
    if(t->finish == 1) return 0;
    
    int nPersent = (int)(100.0*dlnow/dltotal);
    printf("\r[%d] %d->%s %ld, finish: %d, dltotal[%03lf] dlnow[%03lf]", nPersent, t->num, t->url, syscall(SYS_gettid), t->finish, dltotal, dlnow);
    fflush(stdout);
    if(dltotal == dlnow) {
        t->finish = 1;
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
  
  long downloadFileLenth = 0;
  curl_easy_getinfo(handle, CURLINFO_CONTENT_LENGTH_DOWNLOAD, &downloadFileLenth);
  printf("downloadFileLenth: %ld\n", downloadFileLenth);
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
 
static void setup(struct transfer *t, int num, const char *url, const char *outfilename)
{
  char headerfilename[128];
  CURL *hnd;
 
  hnd = t->easy = curl_easy_init();
  
  strncpy(t->url, url, sizeof(t->url));
  t->num = num;
  t->finish = 0;
  t->out = fopen(outfilename, "wb");
  if (t->out == NULL) {
    printf("open %s failed(%s)\n", outfilename, strerror(errno));
    //exit(-1);
  }
  snprintf(headerfilename, 128, "%s.header", outfilename);
 
  t->header = fopen(headerfilename, "wb");
  if (t->header == NULL) {
    printf("open %s failed(%s)\n", outfilename, strerror(errno));
    //exit(-1);
  }

  /* write to this file */ 
  curl_easy_setopt(hnd, CURLOPT_WRITEDATA, t->out);
  curl_easy_setopt(hnd, CURLOPT_HEADERDATA, t->header); //将返回的html主体数据输出到fp指向的文件
  
  /* set the same URL */ 
  curl_easy_setopt(hnd, CURLOPT_URL, url);
 
  /* please be verbose */ 
  curl_easy_setopt(hnd, CURLOPT_VERBOSE, 0L);
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
  struct transfer trans[NUM_HANDLES];
  CURLM *multi_handle;
  int i;
  int still_running = 0; /* keep number of running handles */ 
  int num_transfers = 0;
  const char *url_file;
  FILE *fp;
  char line[200];
  
  signal(SIGSEGV, backtracedump);

  if(argc >= 2) {
    /* if given a number, do that many transfers */ 
    url_file = argv[1];
  } else {
    exit(-1);
  }
    
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
    get_filename_from_url(line, filename);
    setup(&trans[num_transfers], num_transfers, line, filename);
    printf("%d, url: %s, file %s\n", num_transfers, line, filename);

    /* add the individual transfer */ 
    curl_multi_add_handle(multi_handle, trans[num_transfers].easy);
    
    num_transfers++;
    if(num_transfers >= NUM_HANDLES) break;
  }
  fclose(fp);

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
    default:
      /* timeout or readable/writable sockets */ 
      curl_multi_perform(multi_handle, &still_running);
      break;
    }
  }
 
  for(i = 0; i < num_transfers; i++) {
    curl_multi_remove_handle(multi_handle, trans[i].easy);
    curl_easy_cleanup(trans[i].easy);
    if(trans[i].out != NULL) fclose(trans[i].out);
    if(trans[i].header != NULL) fclose(trans[i].header);
  }
 
  curl_multi_cleanup(multi_handle);
 
  return 0;
}
