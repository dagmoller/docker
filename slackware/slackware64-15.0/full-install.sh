#!/bin/bash

defaultMirror=https://mirrors.slackware.com/slackware
slackwareMirror=${slackwareMirror:-https://mirrors.slackware.com/slackware}
slackwareVersion=${slackwareVersion:-slackware64-15.0}

sed 's/^WGETFLAGS=.*/WGETFLAGS="--passive-ftp --no-verbose --no-check-certificate"/g' -i /etc/slackpkg/slackpkg.conf;
sed -e 's/^http//g' -i /etc/slackpkg/mirrors
echo "${slackwareMirror}/${slackwareVersion}/" >> /etc/slackpkg/mirrors

slackpkg -default_answer=yes -batch=on update
slackpkg -default_answer=yes -batch=on upgrade-all

# execute twice
slackpkg -default_answer=yes -batch=on install a/* ap/* d/* e/* f/* k/* kde/* l/* n/* t/* tcl/* x/* xap/* xfce/* y/*
slackpkg -default_answer=yes -batch=on install a/* ap/* d/* e/* f/* k/* kde/* l/* n/* t/* tcl/* x/* xap/* xfce/* y/*

# reinstall
slackpkg -default_answer=yes -batch=on reinstall ca-certificates

find / -xdev -type f -name "*.new" -exec rename ".new" "" {} +

rm -rf /var/cache/packages/*
rm -rf /var/lib/slackpkg/*

sed -e 's/^http//g' -i /etc/slackpkg/mirrors
echo "${defaultMirror}/${slackwareVersion}/" >> /etc/slackpkg/mirrors

cd /etc
ln -sf /usr/share/zoneinfo/America/Sao_Paulo localtime

