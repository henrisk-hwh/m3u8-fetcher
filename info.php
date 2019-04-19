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

function getinfo($base_path) {
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
            echo "[".$index."]   ".$http_url." ".$title."<br>";
            $index++;
        }
        fclose($myfile);
    }
}

getinfo(ASIA_PATH);
getinfo(JPAN_PATH);
?>