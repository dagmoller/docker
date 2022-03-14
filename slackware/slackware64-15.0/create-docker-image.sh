#!/bin/bash

set -e

localPath=${localPath:-/opt/slackware-mirrors}
slackwareVersion=${slackwareVersion:-slackware64-15.0}
dockerTag=${dockerTag:-slackware:full_x64_15.0}

basePath=$(dirname $0)

## Rsync local mirror
cd $basePath
localPath=$localPath slackwareVersion=$slackwareVersion ../scripts/rsync-local-mirror.sh

## Nginx for local mirror
docker run --name nginx-temp --rm -v $localPath:/usr/share/nginx/html:ro -d nginx
nginxAddress=$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' nginx-temp)

## Build Image
docker build --build-arg slackwareMirror=http://$nginxAddress -t $dockerTag .

docker stop nginx-temp

