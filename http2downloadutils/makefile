all: clean http2downloadutils http2download_from_urlfile progressfunc  install
http2downloadutils:
	gcc http2-download.c -lcurl -o $@

http2download_from_urlfile:
	gcc -g http2download_from_urlfile.c -L ~/workspace/webrtc/curl-7.54.0/lib/.libs/ -lcurl -o $@

progressfunc:
	gcc -g progressfunc.c -lcurl -o $@
clean:
	rm -rf out* dl* http2downloadutils http2download_from_urlfile progressfunc

install:
	cp http2download_from_urlfile ../
