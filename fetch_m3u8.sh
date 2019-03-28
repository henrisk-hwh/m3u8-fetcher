#!/bin/bash
#$1 url

. url_utils.sh
. curl_download_utils.sh

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
        wget -P $2 $1 -O $3
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

log() {
    #1 log text
    echo $1
    echo $1 >> $log_file
}

if [ $# -ge 1 ]; then
    echo $1 > url.txt
fi

url=`cat url.txt`
echo url: $url
file=${url##*/}
remote_file=remote_$file
domain=${url%%$file*}
media_dir=./ts
local_file=local.m3u8
log_file=log

protocol=`url_get_protocol $url`
domain=`url_get_domain $url`
path=`url_get_path $url`
file=`url_get_file $url`


mkdir -p $media_dir
rm -rf $log_file

echo fetch domain:$domain, file:$file, remote_file:$remote_file

#fetch m3u8 file
rm -rf $file $local_file
[ -e $remote_file ] || download $url . $remote_file

download_url=""
local_url=""

total_line=`cat $remote_file | grep -v "#" | wc -l`
declare -i cur_finish=0

while read line || [[ -n ${line} ]]
do
	if [ ${line:0:1} != "#" ]; then
		if [ ${line:0:4} == "http" ]; then
            download_url=$line
            local_url=$media_dir/`url_get_path $download_url`/`url_get_file $download_url`
		else
            download_url=${url%\/*}/$line
            local_url=$media_dir/$line
		fi
        echo $local_url >> $local_file
        #download_full_path $download_url $media_dir
        download_full_path_and_check $download_url $media_dir
        if [ $? -ne 0 ]; then
            log "Fetch $download_url failed!!!!"
        fi
        let cur_finish++
        echo "[$cur_finish/$total_line]"'/***********************************************************************/'
    else
        echo $line >> $local_file
	fi
done  < $remote_file
