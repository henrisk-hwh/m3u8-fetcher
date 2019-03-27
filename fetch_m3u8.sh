#!/bin/bash
#$1 url

url_get_protocol() {
    url=$1
    echo ${url%%:*}
}

url_get_domain() {
    url=$1
    domain=${url#*\/\/}
    domain=${domain%%\/*}
    echo $domain
}

url_get_path() {
    url=$1
    domain=${url#*\/\/}
    path=${domain#*\/}
    echo ${path%\/*}
}

url_get_file() {
    url=$1
    echo ${url##*\/}
}

download() {
    #$1 url
    #$2 dst
    #$3 rename
    url=$1
    target_file=${url##*/}
    if [ $# -eq 1 ]; then
        if [ -f $target_file ]; then
            echo $target_file exist! skip $1
            return
        fi
	    echo "download" $1
        wget -q $1
    fi

    if [ $# -eq 2 ]; then
        target_file=$2/$target_file
        if [ -f $target_file ]; then
            echo $target_file exist! skip $1
            return
        fi
	    echo "download" $1 "--->" $2
        wget -P $2 $1
    fi

    if [ $# -eq 3 ]; then
        target_file=$2/$3
        if [ -f $target_file ]; then
            echo $target_file exist! skip $1
            return
        fi
	    echo "download" $1 "--->" $2/$3
        wget -q -P $2 $1 -O $3
    fi
}

url=$1
file=${url##*/}
remote_file=remote_$file
domain=${url%%$file*}
media_dir=./ts
local_file=local.m3u8

url_get_protocol $url
url_get_domain $url
url_get_path $url
url_get_file $url

mkdir -p $media_dir

echo fetch domain:$domain, file:$file, remote_file:$remote_file

#fetch m3u8 file
rm -rf $file $local_file $remote_file
download $url . $remote_file

download_url=""
local_url=""

while read line
do
	if [ ${line:0:1} != "#" ]; then
		if [ ${line:0:4} == "http" ]; then
            download_url=$line
            local_url=$media_dir/${line##*/}
		else
            download_url=$domain/$line
            local_url=$media_dir/$line
		fi
        echo $local_url >> $local_file
        download $download_url $media_dir
    else
        echo $line >> $local_file
	fi
done  < $remote_file
