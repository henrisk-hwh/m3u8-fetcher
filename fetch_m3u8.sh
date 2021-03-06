#!/bin/bash
#$1 url

. contants.sh
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

check_m3u8_media() {
    #1 target_m3u8

    target_m3u8=$1
    cat $target_m3u8 | grep "#EXTM3U"
    
    return $?
}

get_ip_addr() {
	ifconfig -a|grep inet|grep -v 127.0.0.1|grep -v inet6|awk '{print $2}'|tr -d "addr:" | grep 192
}

log() {
    #1 log text
    echo $1
    echo $1 >> $log_file
}

process_info='--/--'
update_remote=0
if [ $# -ge 1 ]; then
    echo $1 > $cache_url_file
    update_remote=1
fi

http_path=http://`get_ip_addr`:$local_http_port/${PWD##*$local_http_root\/}
if [ $# -ge 2 ]; then
    echo $2 > $title_file
	#echo " ------------->>> $http_path/$local_file" >> $title_file
fi

if [ $# -ge 3 ]; then
    process_info=$3
fi

url=`cat $cache_url_file`

protocol=`url_get_protocol $url`
domain=`url_get_domain $url`
path=`url_get_path $url`
file=`url_get_file $url`

remote_file=$remote$file
local_http_file=$local$file


local_path1=$local_http_path${PWD##*$local_http_root}

mkdir -p $media_dir
rm -rf $log_file

[ $update_remote -eq 0 ] || rm -rf $remote_file

echo fetch domain:$domain, file:$file, remote_file:$remote_file

#fetch m3u8 file
rm -rf $file $local_file $local_http_file
if [ ! -e $remote_file ]; then
    #download $url . $remote_file
    download_sample $url $remote_file
    if [ $? -ne 0 ]; then
        rm -rf $remote_file
        exit $ERROR_FETCH_M3U8_URL_FAILED
    fi
fi

check_m3u8_media $remote_file
if [ $? -ne 0 ]; then
    log "$url is not m3u8 file:"
    cat $remote_file
    rm -rf $remote_file
    exit $ERROR_FETCH_M3U8_URL_FAILED
fi

download_url=""
local_url=""

total_line=`cat $remote_file | grep -v "#" | wc -l`
declare -i cur_finish=0
declare -i success_count=0

while read line || [[ -n ${line} ]]
do
	if [ ${line:0:1} != "#" ]; then
		if [ ${line:0:4} == "http" ]; then
            download_url=$line
		else
            download_url=${url%\/*}/$line
		fi
        local_url=$media_dir/`url_get_path $download_url`/`url_get_file $download_url`
        echo $local_url >> $local_file
        echo $http_path/${local_url##*$domain} >> $local_http_file
        #download_full_path $download_url $media_dir
        download_full_path_and_check $download_url $media_dir
        if [ $? -ne 0 ]; then
            log "Fetch $download_url failed!!!!"
        else
            let success_count++
        fi
        let cur_finish++
        echo "[$process_info][$cur_finish/$total_line]"'/***********************************************************************/'
    else
        echo $line >> $local_file
        echo $line >> $local_http_file
	fi
done  < $remote_file

if [ $success_count -eq $total_line ]; then
    touch $done_file
    exit 0
else
    exit $ERROR_FETCH_TS_ELEM_FAILED
fi
