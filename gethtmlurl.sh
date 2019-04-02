#!/bin/bash


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
                echo $url_header/$html_data $title
            elif [[ $html_data =~ "$key1" ]]; then
                html_data=${html_data#*$key1}
                index=${html_data%%'&'*}
                html_data=${html_data#*$index}
                if [[ ${html_data:0:7} = ${key11} ]]; then
                    local_page=${html_data#*$key11}
                    title_start="id=\"a_ajax_$index\">"
                    title=${data#*$title_start}
                    title=${title%%$href_end*}
                    echo $url_header/$key1$index$key11$local_page $title
                fi
            fi
        else
            break
        fi

    done
}

get_html_data_and_title_from_html_file https://127.0.0.1 $1 test
