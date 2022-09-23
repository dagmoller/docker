
# Freeradius

[![Docker Hub](https://img.shields.io/badge/docker-dagmoller%2Ffreeradius-008bb8.svg)](https://registry.hub.docker.com/r/dagmoller/freeradius/)

This is a Freeradius docker image.

## Usage:

```shell
docker run -v <local_path>:/etc/raddb -p 1812:1812/udp -p 1813:1813/udp -itd dagmoller/freeradius:latest
```

