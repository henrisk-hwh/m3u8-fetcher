#!/bin/bash
. contants.sh
. url_utils.sh

fetch_target() {
    #1 url
    #2 title
    #3 dir

    local url=$1
    local title=$2
    local dir=$3

    local file=`url_get_file $url`
    local remote_file=$remote$file

    cd $dir
    if [ ! -e $cache_url_file ]; then
        fetch_m3u8.sh $url "${title}"
    elif [ x`cat $cache_url_file` != x"$url" ]; then
        fetch_m3u8.sh $url "${title}"
    elif [ ! -e $done_file ]; then
        fetch_m3u8.sh
    fi
    cd - > /dev/null
    if [ -e $dir/$done_file ]; then
        echo $PWD fetch $url successfully, done file exist!
        return 0
    elif [ -e $dir/$remote_file ]; then
        echo $PWD fetch $url failed, return code $ERROR_FETCH_TS_ELEM_FAILED
        return $ERROR_FETCH_TS_ELEM_FAILED
    else
        echo $PWD fetch $url failed, return code $ERROR_FETCH_M3U8_URL_FAILED
        return $ERROR_FETCH_M3U8_URL_FAILED
    fi
}

check_index_by_url() {
    #1 index
    #2 check url

    local index=$1
    local check_url=$2

    [ ! -L $index ] && return 1

    [ x`cat $index/$cache_url_file` != x"$check_url" ] && return 1

    return 0
}

find_target_by_index_and_fetch() {
    #1 url
    #2 title
    url=$1
    title=$2

    declare -i local_index=1

    while [ -L $local_index ]; do
        check_index_by_url $local_index $url
        if [ $? -eq 0 ]; then
            echo "Find $url in index($local_index), start to update..."
            fetch_target $url "${title}" $local_index
            local ret=$?
            if [ $ret -eq 0 ]; then
                ret=$local_index
                echo Find_target_by_index_and_fetch $url successfully, index: $local_index
            else
                echo Find_target_by_index_and_fetch $url failed!
            fi
            return $ret # local index or $ERROR_FETCH_M3U8_URL_FAILED $EROOR_FETCH_TS_ELEM_FAILED
        fi
        let local_index++
    done
 
    return 0
}

get_new_index() {
    declare -i local_index=1

    while [ -L $local_index ]; do
        let local_index++
    done

    echo $local_index
}

create_target_by_index_and_fetch() {
    #1 url
    #2 title
    #3 base_path

    local url=$1
    local title=$2
    local base_path=$3
    local file=`url_get_file $url`
    local remote_file=$remote$file
    local media_path=$base_path/${file%.*}
    local ret=$?

    [ -d $media_path ] || mkdir $media_path
    
    fetch_target $url "${title}" $media_path
    ret=$?
    if [ $ret -eq 0 ]; then
        echo Create_target_by_index_and_fetch $url successfully, title: $title
    fi

    return $ret
}


url_file=url.txt

if [ $# -eq 1 ]; then
    url_file=$1
fi

rm -rf $list_fetch_file

base_path=$base_dir
mkdir -p $base_path

while read line || [[ -n ${line} ]]
do
    url=`echo $line | awk '{print $1}'`
    title=${line#*$url}
    if [[ ! $url =~ "http" ]]; then
        continue
    fi

    echo fetch $url have not find index, try to create!
    create_target_by_index_and_fetch $url "${title}" $base_path
    ret=$? #index

    if [ $ret -eq $ERROR_FETCH_M3U8_URL_FAILED ]; then
        #fetch m3u8 url failed
        echo fetch m3u8 url failed
        echo $url $ret failed, message:get M3U8 file failed >> $list_fetch_file 
    elif [ $ret -eq $ERROR_FETCH_TS_ELEM_FAILED ]; then
        #fetch url success, buf fetch ts elem failed
        echo fetch url success, buf fetch ts elem failed
        echo $url $ret failed, message: get some TS files failed >> $list_fetch_file 
    else
        echo $url $ret OK ---- local url: http://127.0.0.1/$ret/local.m3u8 >> $list_fetch_file

    fi
    echo "--------------------------------------------------------------------------------------------------------------"
done < $url_file
