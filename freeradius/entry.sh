#!/bin/sh

chmod 755 /etc/raddb
/usr/sbin/radiusd -f -l stdout

