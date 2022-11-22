#!/bin/bash

basepath=/opt/myvd
confpath=$basepath/conf
libpath=$basepath/lib
etcpath=/etc/myvd

# Populate config path if file difers
for file in $(ls -A $etcpath); do
	etcfile=$etcpath/$file
	conffile=$confpath/$file

	if [ -e $confpath/$file ]; then
		rm -rf $confpath/$file
	fi
	ln -s $etcpath/$file $confpath/$file

	if [ $(echo $name | grep -ic '.jar') -gt 0 ]; then
		ln -s $etcpath/$file $libpath/$file
	fi
done

cd $basepath/bin
./myvd.sh start

