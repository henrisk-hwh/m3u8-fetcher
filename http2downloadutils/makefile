all: clean http2downloadutils http2download_from_urlfile
http2downloadutils:
	gcc http2download.c -lcurl -o $@

http2download_from_urlfile:
	gcc http2download_from_urlfile.c -lcurl -o $@
clean:
	rm -rf out* http2downloadutils http2download_from_urlfile
