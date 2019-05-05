#!/bin/bash
#$1 url

. contants.sh
. url_utils.sh
. curl_download_utils.sh

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

download_urlfile_by_http2() {
    #1 url file
    #2 total elems

    local url_file=$1
    let total=$2

    let need=`cat $url_file | wc -l`
    let finish=total-need

    http2download_from_urlfile -f $url_file -n 50 -i "[$process_info][$finish/$total]"
    #http2download_from_urlfile $url_file &> /dev/null
}

download_ifneed() {
    #1 target urlfile
    #2 media_dir
    #3 retry
    #4 failed file
    #5 total elems

    local urlfile=$1
    local media_dir=$2
    local retry=$3
    local failed_file=$4
    local total=$5

    local should_download="no"
    local local_file=""
    local cookies_file=""
    local target_dir=""
    local ret=0
    local tmp_url_file=$download_url_file.$retry
    #check frist
    rm -rf $download_tmp_dir/$tmp_url_file
    while read line || [[ -n ${line} ]]
    do
        if [ ${line:0:1} != "#" ]; then
            if [ ${line:0:4} == "http" ]; then
                download_url=$line
            else
                download_url=${url%\/*}/$line
            fi
            local_file=$media_dir/`url_get_path $download_url`/`url_get_file $download_url`
            check_data_by_header $local_file $local_file$header
            [ $? -eq 0 ] && continue
            cookies_file=$download_cookies_dir/`url_get_file $download_url`
            [ -f $cookies_file$header ] && clean_file $cookies_file$header
            check_data_by_header $cookies_file $cookies_file$header
            ret=$?
            if [ $ret -eq 0 ]; then
                target_dir=$media_dir/`url_get_path $download_url`
                mkdir -p $target_dir
                mv $cookies_file $cookies_file$header $target_dir
                continue
            elif [ $ret -eq $ERROR_CHECK_DATA_HTTP_CODE_FAILED ]; then
                echo "rm -rf $cookies_file $cookies_file$header"
                rm -rf $cookies_file $cookies_file$header
            fi

            echo $download_url >> $download_tmp_dir/$tmp_url_file
            should_download="yes"
        fi
    done  < $urlfile

    #download if need
    if [ $should_download = "yes" ]; then
        cd $download_cookies_dir
        download_urlfile_by_http2 ../$download_tmp_dir/$tmp_url_file $total
        cd - > /dev/null
    else
        return 0
    fi

    #copy to dir
    should_download="no"
    while read line || [[ -n ${line} ]]
    do
        if [ ${line:0:1} != "#" ]; then
            if [ ${line:0:4} == "http" ]; then
                download_url=$line
            else
                download_url=${url%\/*}/$line
            fi
            local_file=$download_cookies_dir/`url_get_file $download_url`
            [ -f $local_file$header ] && clean_file $local_file$header
            check_data_by_header $local_file $local_file$header
            if [ $? -eq 0 ]; then
                target_dir=$media_dir/`url_get_path $download_url`
                mkdir -p $target_dir
                mv $local_file $local_file$header $target_dir
            else
                echo $download_url >> $failed_file
                should_download="yes"
            fi
        fi
    done  < $download_tmp_dir/$tmp_url_file

    if [ $should_download = "yes" ]; then
        return 1
    else
        return 0
    fi
}

process_info='--/--'
update_remote=0
if [ $# -ge 1 ]; then
    echo $cache_url_file
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

download_tmp_dir=./tmp
download_cookies_dir=./cookies
download_url_file=tmp_url
local_path1=$local_http_path${PWD##*$local_http_root}

rm -rf $download_tmp_dir
mkdir -p $download_tmp_dir
mkdir -p $download_cookies_dir

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

target_url_file=$remote_file
total_elems=`cat $target_url_file | grep http | wc -l`

failed_file=$download_tmp_dir/failed_file
declare -i retry=0
while [ $retry -le 50 ]; do
    failed_file_retry=$failed_file.$retry
    download_ifneed $target_url_file $media_dir $retry $failed_file_retry $total_elems
    [ $? -eq 0 ] && break
    target_url_file=$failed_file_retry
    echo target_url_file $target_url_file
    let retry++
    echo "rerty --- $retry, `cat $target_url_file | wc -l` elem left!"
done

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
        if [ ! -e $local_url ]; then
            log "Fetch $download_url failed!!!!"
        else
            let success_count++
        fi
        echo $local_url >> $local_file
        echo $http_path/${local_url##*$domain} >> $local_http_file
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
