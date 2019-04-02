
get_m3u8_url_from_html_file() {
    #1 html file
    #return m3u8 url
    local url='https://m3u8.cdnpan.com'
    local data=`cat $1 | grep baiduyunbo`
    echo $data
    local id=${data#*baiduyunbo}
    id=${id#*id=}
    echo $id
    id=${id%%\"*}
    echo $url/$id.m3u8
}

get_m3u8_url_from_html_file $1
