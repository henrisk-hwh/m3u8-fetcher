<?php

header("Content-Type:text/html; charset=utf-8");

const DONE_FLAG = "done";
const M3U8_FILE = "local.m3u8";
const ASIA_PATH = "asia/";
const JPAN_PATH = "jpan/";
const LIST_FILE="list_result";

function gettitle($mediapath) {
    $title_path = $mediapath."/"."title.txt";
    $err_info = "Unable to open file(".$title_path.")!";
    $title_file = fopen($title_path, "r") or die($err_info);
    $title = fgets($title_file);
    fclose($title_file);
    return $title;
}

function getinfo($base_path, $elem_hook) {
    $target_file = $base_path.LIST_FILE;

    $index = 1;
    if(file_exists($target_file)) {
        $err_info = "Unable to open file(".$target_file.")!";
        $myfile = fopen($target_file, "r") or die($err_info);
        while(!feof($myfile)){//函数检测是否已到达文件末尾 
            $elem = fgets($myfile);
            $arr = explode(" ", $elem);
            //echo $arr[0].$arr[1].$arr[2];
            if ( $arr[0] != DONE_FLAG ) continue;
            //print_r($arr);
            $meida_path = substr($arr[1], strpos($arr[1],'/')+1); //去除冗余的'./'
            $meida_path = $base_path.$meida_path;
            $meida_file = $meida_path."/".M3U8_FILE;
            $title = gettitle($meida_path);
            
            $http_url = "http://".$_SERVER["HTTP_HOST"]."/".$meida_file;
            //echo "[".$index."]   ".$http_url." ".$title."<br>";
            elem_hook($index, $http_url, $title);
            $index++;
        }
        fclose($myfile);
    }
}
function elem_hook($index, $http_url, $title) {
print <<<EOT
    <button onclick="play('$http_url', '1111')"><h2>[$index]   $http_url $title</h2></button>

EOT;
}
print <<<EOT

<!DOCTYPE html>
<html>

    <head>
        <meta charset="UTF-8">
        <title>ckplayer</title>
        
        <style type="text/css">
            body {
                margin: 0;
                padding: 0px;
                font-family: "Microsoft YaHei", YaHei, "微软雅黑", SimHei, "黑体";
                font-size: 10px;
            }
            p{
                padding-left: 2em;
            }
        </style>

    </head>

    <body>
    <script>
        function play(playerurl, title) {
            var url = "./player.html?url=" + playerurl + ",title=" + title;
            window.open(url, "__blank")
        }
    </script>
EOT;
getinfo(ASIA_PATH,"elem_hook");
getinfo(JPAN_PATH,"elem_hook");
print <<<EOT
    </body>

</html>
EOT;
?>