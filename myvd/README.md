
# My Virtual Directory (myvd)

[![Docker Hub](https://img.shields.io/badge/docker-dagmoller%2Fmyvd-008bb8.svg)](https://registry.hub.docker.com/r/dagmoller/myvd/)

This is a myvd (My Virtual Directory) docker image.

## Usage:

```shell
docker run -v <local_path>:/etc/myvd -p 10983:10983 -itd dagmoller/myvd:1.0.9
```

### Environment Variables

* `JRE_VERSION` - JRE version to be installed (default: openjdk17-jre)
* `MYVD_VERSION` - myvd version to be installed (default: 1.0.9)

### Volumes

* `/etc/myvd` - Configuration path

