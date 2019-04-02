#!/bin/bash

. contants.sh
. url_utils.sh
. curl_download_utils.sh

get_m3u8_url_from_html_file() {
    #1 html file
    #return m3u8 url
    local url='https://m3u8.cdnpan.com'
    local data=`cat $1 | grep -a baiduyunbo`
    local id=${data#*baiduyunbo}
    id=${id#*id=}
    id=${id%%\"*}
    echo $url/$id.m3u8
}

fetch_m3u8_url_and_title_from_html_data_file() {
    #1 html_data file
    #2 store file

    local html_data_file=$1
    local store_file=$2

    local total=`cat $html_data_file | wc -l`
    declare -i process=0
    while read line || [[ -n ${line} ]]
    do
        let process++
        local index=`echo $line | awk '{print $1}'`
        local html_url=`echo $line | awk '{print $2}'`
        local title=${line#*$html_url}
        local file=`url_get_file $html_url`
        local tmp_file=tmp_$index.html
        if [ ! -e $tmp_file ]; then
            download_sample $html_url $tmp_file
            if [ $? -ne 0 ]; then
                rm -rf $tmp_file
                continue
            fi
        fi
        cat $tmp_file | grep -a "baiduyunbo" > /dev/null
        if [ $? -ne 0 ]; then
            rm -rf $tmp_file
            continue
        fi
        
        local m3u8_url=`get_m3u8_url_from_html_file $tmp_file`
        echo $m3u8_url $title >> $store_file
        echo "[page: $PAGE/$PAGES][$process/$total] ------------------------------------"
    done < $html_data_file
}

get_html_data_and_title_from_html_file() {
    #1 url_header
    #2 html file
    #3 store file
    #return json {"html_data"="$html_data","title"="$title"}
    local href_start='a href="'
    local href_end='</a>'
    local key='html_data'
    local key1='read.php?tid='
    local key11='&fpage='
    local html_data=''
    local index=''
    local title=''
    local url_header=$1
    local data=`cat $2`
    local store_file=$3
    local title_start=''
    local local_page=''
    while true
    do
        if [[ $data =~ "$href_start" ]]; then
            data=${data#*$href_start}
            html_data=${data%%\"*}
            data=${data#*$html_data}
            if [[ $html_data =~ "$key" ]]; then
                index=${html_data%.*}
                index=${index##*\/}
                title_start="id=\"a_ajax_$index\">"
                title=${data#*$title_start}
                title=${title%%$href_end*}
                #echo \{\"html_data\"=\"$html_data\", \"title\"=\"$title\"\}
                echo $index $url_header/$html_data $title >> $store_file
            elif [[ $html_data =~ "$key1" ]]; then
                html_data=${html_data#*$key1}
                index=${html_data%%'&'*}
                html_data=${html_data#*$index}
                if [[ ${html_data:0:7} = ${key11} ]]; then
                    local_page=${html_data#*$key11}
                    title_start="id=\"a_ajax_$index\">"
                    title=${data#*$title_start}
                    title=${title%%$href_end*}
                    echo $index $url_header/$key1$index$key11$local_page $title >> $store_file
                fi
            fi
        else
            break
        fi

    done
}

#1 url
#2 page end
url=$1
pages=$2
pages_start=0
refresh=yes

if [ $# -eq 3 ]; then
    page_start=$2
    pages=$3
fi

if [ $# -eq 4 ]; then
    page_start=$2
    pages=$3
    refresh=$4
fi

protocol=`url_get_protocol $url`
domain=`url_get_domain $url`
path=`url_get_path $url`

export PAGES=$pages
#$1 data_file
rm -rf m3u8_title.txt
mkdir -p tmp
cd tmp

declare -i page=$page_start
while [ $page -le $pages ]; do
    export PAGE=$page
    page_url=$url'&page='$page
    rm -rf html_data_page_$page.txt m3u8_title_page_$page.txt
    if [ ! -e $page.php ] || [ $refresh = "yes" ]; then
        download_sample $page_url $page.php
    fi
    get_html_data_and_title_from_html_file "$protocol://$domain/$path" $page.php  html_data_page_$page.txt
    fetch_m3u8_url_and_title_from_html_data_file html_data_page_$page.txt m3u8_title_page_$page.txt
    cat m3u8_title_page_$page.txt >> ../m3u8_title.txt
    let page++
done
