#!/bin/sh
file=$1
local_file=$2
media_dir=$3
rm -rf $local_file
while read line
do
echo $line | grep http >/dev/null
if [ $? -eq 0 ]; then
	real_file=${line##*/}
	new_uri=$media_dir/$real_file
	echo $new_uri >> $local_file
else
	echo $line >> $local_file
fi
done  < $file
