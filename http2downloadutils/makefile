all: clean http2downloadutils http2download_from_urlfile install
http2downloadutils:
	gcc http2download.c -lcurl -o $@

http2download_from_urlfile:
	gcc -g http2download_from_urlfile.c -lcurl -o $@
clean:
	rm -rf out* http2downloadutils http2download_from_urlfile

install:
	cp http2download_from_urlfile ../
