url_get_protocol() {
    local url=$1
    echo ${url%%:*}
}

url_get_domain() {
    local url=$1
    local domain=${url#*\/\/}
    local domain=${domain%%\/*}
    echo $domain
}

url_get_path() {
    local url=$1
    local domain=${url#*\/\/}
    local path=${domain#*\/}
    echo ${path%\/*}
}

url_get_file() {
    local url=$1
    echo ${url##*\/}
}
