#!/bin/bash
. contants.sh
. url_utils.sh

fetch_target() {
    #1 url
    #2 dir
    local url=$1
    local dir=$2

    local file=`url_get_file $url`
    local remote_file=$remote$file

    cd $dir
    if [ ! -e $cache_url_file ]; then
        fetch_m3u8.sh $url
    elif [ x`cat $cache_url_file` != x"$url" ]; then
        fetch_m3u8.sh $url
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
    url=$1

    declare -i local_index=1

    while [ -L $local_index ]; do
        check_index_by_url $local_index $url
        if [ $? -eq 0 ]; then
            echo "Find $url in index($local_index), start to update..."
            fetch_target $url $local_index
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
    #2 base_path

    local url=$1
    local base_path=$2
    local file=`url_get_file $url`
    local remote_file=$remote$file
    local media_path=$base_path/${file%.*}
    local ret=$?
    
    [ -d $media_path ] || mkdir $media_path
    
    fetch_target $url $media_path
    ret=$?
    if [ $ret -eq 0 ]; then
        local index=`get_new_index`
        ln -s $media_path $index
        ret=$index
        echo Create_target_by_index_and_fetch $url successfully, index: $index
    fi

    return $ret
}


url_file=url.txt

if [ $# -eq 1 ]; then
    url_file=$1
fi

rm -rf $list_fetch_file

base_path=media
mkdir -p $base_path

while read line || [[ -n ${line} ]]
do
    url=$line

    find_target_by_index_and_fetch $url
    ret=$?
    if [ $ret -eq 0 ]; then
        echo fetch $url have not find index, try to create!
        create_target_by_index_and_fetch $url $base_path
        ret=$? #index
    fi

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

    exit 1

    if [ $? -ne 0 ]; then
        create_target_by_index_and_fetch $url $media_path
    fi
    file=`url_get_file $url`
    remote_file=$remote$file
    media_path=$base_path/${file%.*}

    [ -d $media_path ] || mkdir $media_path
    cd $media_path
    if [ ! -e $cache_url_file ]; then
        fetch_m3u8.sh $url
    elif [ x`cat $cache_url_file` != x"$url" ]; then
        fetch_m3u8.sh $url
    elif [ ! -e $done_file ]; then
        fetch_m3u8.sh
    fi
    if [ -e $done_file ]; then
        cd -
        echo $url $index OK ---- local url: http://127.0.0.1/$index/local.m3u8 >> $list_fetch_file
        ln -s $media_path $index
        let index++
    else
        cd -
        rm -rf $index
        echo $url failled >> $list_fetch_file
    fi
