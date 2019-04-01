#!/bin/bash

. contants.sh
. url_utils.sh
. curl_download_utils.sh

get_m3u8_url_from_html_file() {
    #1 html file
    #return m3u8 url
    local url='https://m3u8.cdnpan.com'
    local data=`cat $1 | grep baiduyunbo`
    local id=${data#*id=}
    id=${id%%\"*}
    echo $url/$id.m3u8
}

fetch_m3u8_url_and_title_from_html_data_file() {
    #1 html_data file
    local html_data_file=$1
    while read line || [[ -n ${line} ]]
    do
        local html_url=`echo $line | awk '{print $1}'`
        local title=${line#*$html_data}
        local file=`url_get_file $html_url`
        local tmp_file=tmp_$file
        download_sample $html_url $tmp_file
        if [ $? -ne 0 ]; then
            rm -rf $tmp_file
            continue
        fi
        cat $tmp_file | grep "baiduyunbo"
        if [ $? -ne 0 ]; then
            rm -rf $tmp_file
            continue
        fi
        
        local m3u8_url=`get_m3u8_url_from_html_file tmp_$html_url`
        echo $m3u8_url $title
    done < $html_data_file
}

get_html_data_and_title_from_html_file() {
    #1 url_header
    #2 html file
    #return json {"html_data"="$html_data","title"="$title"}
    local href_start='a href="'
    local href_end='</a>'
    local key='html_data'
    local html_data=''
    local index=''
    local title=''
    local url_header=$1
    local data=`cat $2`
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
                echo $url_header/$html_data $title
            fi
        else
            break
        fi

    done
}

#$1 data_file

get_html_data_and_title_from_html_file "http://127.0.0.1" $1 > html_data.txt
fetch_m3u8_url_and_title_from_html_data_file html_data.txt
