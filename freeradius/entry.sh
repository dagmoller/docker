#!/bin/sh

echo 
echo "Checking config path..."
test -d /etc/raddb || mkdir /etc/raddb
if [ ! -e /etc/raddb/radiusd.conf ]; then
	echo "Populating /etc/raddb..."
	cp -a /etc/_raddb.default/* /etc/raddb/
fi
echo "Adjusting config files permissions..."
chmod 755 /etc/raddb

echo "Starting radisud..."
/usr/sbin/radiusd -f -l stdout

