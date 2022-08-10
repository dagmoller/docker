#!/bin/bash

basepath=/opt/myvd
confpath=$basepath/conf
etcpath=/etc/myvd

# Populate config path if file difers
for item in $etcpath/*; do
	name=$(basename $item)
	if [ -e $confpath/$name ]; then
		rm -rf $confpath/$name
	fi
	ln -s $item $confpath/$name
done

cd $basepath/bin
./myvd.sh start

