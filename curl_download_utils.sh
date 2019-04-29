clean_file() {
    #1 file
    local file=$1
    #dos2unix $file
    sed -i 's///g' $file
}

download_http_header() {
    #1 url
    #2 base path
    #3 header file name
    local url=$1
    local base_path=$2
    local header_file=$3
    curl -I $url > $base_path/$header_file
    clean_file $base_path/$header_file
    return $#
}

download_http_data_and_header() {
    #1 url
    #2 base path
    #3 data file name
    #4 header file name
    
    [ $# -eq 4 ] || return 1

    local url=$1
    local base_path=$2
    local data_file_name=$3
    local header_file_name=$4

    local target_path=$base_path
    local target_header_path=$target_path

    echo "curl $url -D $header_file_name -o $data_file_name"
    curl $url -D $header_file_name -o $data_file_name

    if [ $? -eq 0 ]; then
        mkdir -p $target_header_path
        mv $data_file_name $target_path
        mv $header_file_name $target_header_path
        clean_file $target_header_path/$header_file_name
        return 0
    else
        rm -rf $data_file_name $header_file_name
        echo "Curl download $url failed!"
        return 1
    fi
}

check_data_by_header() {
    #1 target_data_file
    #2 target_header_file

    #success return 0

    local target_data_file=$1
    local target_header_file=$2

    #echo check $target_data_file $target_header_file
    [ -e $target_data_file ] || return $ERROR_CHECK_DATA_NO_DATAFILE
    [ -e $target_header_file ] || return $ERROR_CHECK_DATA_NO_HEADERFILE

    local http_code=`cat $target_header_file | grep -i http | awk '{print $2}'`
    http_code=${http_code%\n*}

    #http 200 成功处理了请求
    #http 206 继续请求一个未完成的下载
    if [ x"$http_code" != "x200" ] && [ x"$http_code" != "x206" ]; then
        echo "Check http code($http_code) failed, header file: $target_header_file"
        return $ERROR_CHECK_DATA_HTTP_CODE_FAILED
    fi

    local target_data_file_length=`ls -l $target_data_file | awk '{print $5}'`
    local target_header_file_content_length=""
    if [ x"$http_code" = "x200" ]; then
        target_header_file_content_length=`cat $target_header_file | grep -i "content-length" | awk '{printf $2}'`
    elif [ x"$http_code" = "x206" ]; then
        target_header_file_content_length=`cat $target_header_file | grep -i "content-range"`
        target_header_file_content_length=${target_header_file_content_length#*\/}
    fi
    
    
    if [ x"$target_data_file_length" = x"${target_header_file_content_length%$*}" ]; then
        echo "Check -- $target_data_file -- by http($http_code) content-length success!"
        return 0
    else
        echo "data-file-length:   " $target_data_file_length
        echo "http content-length:" $target_header_file_content_length $http_code
        echo Check -- $target_data_file -- by http content-length failed!
        return $ERROR_CHECK_DATA_LENGHT_FAILED
    fi
}

download_full_path_and_check() {
    #1 url
    #2 dst
    
    local url=$1
    local dst=$2

    local url_path=`url_get_path $url`
    local url_file=`url_get_file $url`

    local header_file=$url_file$header

    local data_file_path=$dst/$url_path

    local data_file_full=$data_file_path/$url_file
    local header_file_full=$data_file_path/$header_file

    declare -i retry=1
    while [ $retry -le 3 ]; do
        let retry++
        check_data_by_header $data_file_full $header_file_full
        ret=$?
        if [ $ret -eq 0 ]; then
            echo $url download and check sucessfully!
            return 0
        elif [ $ret -eq $ERROR_CHECK_DATA_NO_HEADERFILE ]; then
            echo "download $url header only to check the exist file: $data_file_full"
            download_http_header $url $dst/$url_path $header_file
        else
            download_http_data_and_header $url $dst/$url_path $url_file $header_file
        fi
    done
    return 1
}

download_sample() {
    #1 url
    #2 rename

    local url=$1
    local target_file=$2
    echo curl $url -o $target_file
    curl $url -o $target_file
    return $?
}
