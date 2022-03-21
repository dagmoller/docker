
FROM debian:bullseye

RUN \
	apt update; \
	apt install -y wget gnupg; \
	wget -O- https://deb.kamailio.org/kamailiodebkey.gpg | apt-key add -; \
	echo "deb http://deb.kamailio.org/kamailio55 bullseye main" > /etc/apt/sources.list.d/kamailio.list; \
	echo "deb-src http://deb.kamailio.org/kamailio55 bullseye main" >> /etc/apt/sources.list.d/kamailio.list; \
	apt update; \
	apt install -y kamailio kamailio-postgres-modules; \
	apt-get clean && rm -rf /var/lib/apt/lists/*; \
	cp -rf /etc/kamailio /etc/kamailio.orig

VOLUME /etc/kamailio

ENTRYPOINT ["kamailio", "-DD", "-E"]

