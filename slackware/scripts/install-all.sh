#!/bin/bash

set -e

slackwareMirror=${slackwareMirror:-/opt/slackware-mirrors}
slackwareVersion=${slackwareVersion:-slackware64-15.0}

sed -e 's/^htt.*/#/g' -i /etc/slackpkg/mirrors
if [ $(echo $slackwareMirror | grep -ic "http") -ne 0 ]; then
	echo $slackwareMirror >> /etc/slackpkg/mirrors
else
	echo "file:/${slackwareMirror}/${slackwareVersion}/" >> /etc/slackpkg/mirrors
fi

slackpkg -default_answer=yes -batch=on update
slackpkg -default_answer=yes -batch=on upgrade-all

# execute twice
slackpkg -default_answer=yes -batch=on install a/* ap/* d/* e/* f/* k/* kde/* l/* n/* t/* tcl/* x/* xap/* xfce/* y/*
slackpkg -default_answer=yes -batch=on install a/* ap/* d/* e/* f/* k/* kde/* l/* n/* t/* tcl/* x/* xap/* xfce/* y/*

find / -xdev -type f -name "*.new" -exec rename ".new" "" {} +

rm -rf /var/cache/packages/*
rm -rf /var/lib/slackpkg/*

cd /etc
ln -sf /usr/share/zoneinfo/America/Sao_Paulo localtime

