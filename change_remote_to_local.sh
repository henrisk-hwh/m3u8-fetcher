#!/bin/bash
file=$1
local_file=$2
media_dir=$3
rm -rf $local_file
while read line || [[ -n ${line} ]]
do
	echo $line
done  < $file
