
# Debian docker with systemd

This is an debian docker with systemd.

## Usage:

```shell
docker run --privileged -v /sys/fs/cgroup:/sys/fs/cgroup:ro -d dagmoller/debian-systemd:<tag>
```

## Volumes

* `/sys/fs/cgroup` - host cgroup bind (ro)

