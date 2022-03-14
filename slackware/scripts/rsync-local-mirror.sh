#!/bin/bash

localPath=${localPath:-/opt/slackware-mirrors}
remoteUrl=${remoteUrl:-rsync://slackware.nl/mirrors/slackware}
slackwareVersion=${slackwareVersion:-slackware64-15.0}

test -d $localPath || mkdir -p $localPath
remoteRsync=${remoteUrl}/${slackwareVersion}

rsync -av --progress --delete --delete-excluded --bwlimit 0 --exclude pasture --exclude source $remoteRsync $localPath/

