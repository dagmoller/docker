
FROM liveslak/slackware:base_x64_14.2
LABEL org.opencontainers.image.authors="Diego Aguirre <aguirre@dagcs.com>"

ENV MEDIATOMB_PORT=50500

EXPOSE 50500/tcp
EXPOSE 50500/udp
EXPOSE 1900/tcp
EXPOSE 1900/udp

VOLUME /var/lib/mediatomb

ENTRYPOINT /entrypoint.sh

COPY *.t?z /root/

COPY entrypoint.sh /

RUN \
  chmod 755 /entrypoint.sh; \
  cd /root; \
  installpkg *.t?z; \
  rm -rf *.t?z; \
  \
  sed 's/^WGETFLAGS=.*/WGETFLAGS="--passive-ftp --no-verbose --no-check-certificate"/g' -i /etc/slackpkg/slackpkg.conf; \
  sed 's/^http:.*/http:\/\/mirrors.slackware.com\/slackware\/slackware64-14.2\//g' -i /etc/slackpkg/mirrors; \
  \
  slackpkg update; \
  while [ $(ldd /usr/bin/mediatomb | grep -ic 'not found') -gt 0 ]; do ldd /usr/bin/mediatomb | grep not | awk '{print $1}' | while read word; do slackpkg file-search $word; done | grep uninstalled | head -1 | awk '{print $3}' | xargs slackpkg install; done

