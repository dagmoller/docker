#!/bin/bash

basepath=/opt/myvd
confpath=$basepath/conf
confdefault=${confpath}.default
confetc=/etc/myvd

# Populate default config if not exists
for item in $confdefault/*; do
	name=$(basename $item)
	if [ ! -e $confetc/$name ]; then
		cp -rf $item $confetc/
	fi
done

cd $basepath/bin
./myvd.sh start

logfile=$basepath/logs/myvd.log
maxwait=5
while [ $maxwait > 0 ]; do
	test -f $logfile && break || sleep 1
	maxwait=$(($maxwait - 1))
done
test -f $logfile && tail -f $logfile

