
# Mediatomb for Samsung TVs

[![Docker Hub](https://img.shields.io/badge/docker-dagmoller%2Fmediatomb-008bb8.svg)](https://registry.hub.docker.com/r/dagmoller/mediatomb/)

This is a Mediatomb patched for Samsung TVs correct subtitles support.

## Usage:

```shell
docker run -v <local_path>:/var/lib/mediatomb -v <local_media_path>:\<contatiner_media_path>:ro -itd dagmoller/mediatomb:0.12.1
```

## Access
http://localhost:50500

### Environment Variables

* `MEDIATOMB_PORT` - Port to bind (default: 50500)
* `MEDIATOMB_CONFIG` - Config filename (default: config-samsung.xml)

### Volumes

* `/var/lib/mediatomb` - Configuration and Database path

