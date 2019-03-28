#!/bin/bash
. contants.sh
. url_utils.sh

url_file=url.txt

if [ $# -eq 1 ]; then
    url_file=$1
fi

rm -rf $list_fetch_file

declare -i index=1
while read line || [[ -n ${line} ]]
do
    url=$line
    file=`url_get_file $url`
    remote_file=$remote$file
    [ -d $index ] || mkdir $index
    cd $index
    if [ ! -e $cache_url_file ]; then
        fetch_m3u8.sh $url
    elif [ x`cat $cache_url_file` != x"$url" ]; then
        fetch_m3u8.sh $url
    elif [ ! -e $done_file ]; then
        fetch_m3u8.sh
    fi
    if [ -e $done_file ]; then
        cd -
        echo $url $index OK >> $list_fetch_file
        let index++
    else
        cd -
        rm -rf $index
        echo $url failled >> $list_fetch_file
    fi
done < $url_file
