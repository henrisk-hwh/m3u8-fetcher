#!/bin/bash
#$1 url

url_get_protocol() {
    local url=$1
    echo ${url%%:*}
}

url_get_domain() {
    local url=$1
    local domain=${url#*\/\/}
    local domain=${domain%%\/*}
    echo $domain
}

url_get_path() {
    local url=$1
    local domain=${url#*\/\/}
    local path=${domain#*\/}
    echo ${path%\/*}
}

url_get_file() {
    local url=$1
    echo ${url##*\/}
}

download() {
    #$1 url
    #$2 dst
    #$3 rename
    local url=$1
    local target_file=${url##*/}
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

download_full_path() {
    #$1 url     #need
    #$2 dst     #need

    local url=$1
    local dst=$2

    echo dowlaod_full_path $1 $2
    local path=`url_get_path $url`
    local file=`url_get_file $url`

    mkdir -p $dst/$path

    if [ $# -eq 2 ]; then
        local target_file=$dst/$path/$file
        if [ -f $target_file ]; then
            echo $target_file exist! skip $url
            return
        fi
	    echo "download" $url "--->" $target_file
        wget -P $dst/$path $1
    fi
}

url=$1
file=${url##*/}
remote_file=remote_$file
domain=${url%%$file*}
media_dir=./ts
local_file=local.m3u8

protocol=`url_get_protocol $url`
domain=`url_get_domain $url`
path=`url_get_path $url`
file=`url_get_file $url`

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
            echo url: $url
            echo line: $line
            download_url=${url%\/*}/$line
            echo dowload_url: $download_url
            local_url=$media_dir/$line
		fi
        echo $local_url >> $local_file
        download_full_path $download_url $media_dir
    else
        echo $line >> $local_file
	fi
    echo "\n\n\n\n"
done  < $remote_file
