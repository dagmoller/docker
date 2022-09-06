#!/bin/bash

basepath=/opt/myvd
confpath=$basepath/conf
libpath=$basepath/lib
etcpath=/etc/myvd

# Populate config path if file difers
for item in $etcpath/*; do
	name=$(basename $item)

	if [ -e $confpath/$name ]; then
		rm -rf $confpath/$name
	fi
	ln -s $item $confpath/$name

	if [ $(echo $name | grep -ic '.jar') -gt 0 ]; then
		ln -s $item $libpath/$name
	fi
done

cd $basepath/bin
./myvd.sh start

