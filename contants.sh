#fetch_m3u8
media_dir=./ts
local_file=local.m3u8
log_file=log
done_file=fetch_done
remote=remote_
local=local_
cache_url_file=url.txt
title_file=title.txt

local_http_root='db/db'
local_http_port='8888'
local_http_path="http://127.0.0.1"

ERROR_FETCH_M3U8_URL_FAILED=200
ERROR_FETCH_TS_ELEM_FAILED=201
ERROR_CHECK_DATA_LENGHT_FAILED=202
ERROR_CHECK_DATA_HTTP_CODE_FAILED=203
ERROR_CHECK_DATA_NO_DATAFILE=204
ERROR_CHECK_DATA_NO_HEADERFILE=205

#list_fetch
list_fetch_file=list_result
base_dir=./media

#curl download
header=.header
