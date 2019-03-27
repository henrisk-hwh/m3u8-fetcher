#!/bin/sh
#$1 url
url=$1
file=${url##*/}
domain=${url%%$file*}
echo fetch domain:$domain, file:$file

rm -rf $file
wget $url

media_dir=./ts
mkdir -p $media_dir
cd $media_dir
cat ../$file | grep http | xargs wget {}\;
cd -

change_remote_to_local.sh $file local.m3u8 $media_dir
