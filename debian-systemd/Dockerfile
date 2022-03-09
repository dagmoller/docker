
#
# to run this image from slackware 15.0 host we need to mount systemd cgroup on custom path
# mkdir /sys/fs/cgroup/nonsystemd
# mount -t cgroup -o none,name=systemd systemd /sys/fs/cgroup/nonsystemd 
#

ARG tag
FROM debian:$tag

ENV container=docker
ENV LC_ALL=C
ENV DEBIAN_FRONTEND=noninteractive

STOPSIGNAL SIGRTMIN+3

RUN apt-get update \
    && apt-get install -y systemd systemd-sysv init procps \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN rm -f /lib/systemd/system/multi-user.target.wants/* \
    /etc/systemd/system/*.wants/* \
    /lib/systemd/system/local-fs.target.wants/* \
    /lib/systemd/system/sockets.target.wants/*udev* \
    /lib/systemd/system/sockets.target.wants/*initctl* \
    /lib/systemd/system/sysinit.target.wants/systemd-tmpfiles-setup* \
    /lib/systemd/system/systemd-update-utmp*

VOLUME [ "/sys/fs/cgroup" ]

CMD ["/sbin/init"]

