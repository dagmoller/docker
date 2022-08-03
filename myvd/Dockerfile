
FROM alpine:3.16

ENV JRE_VERSION=openjdk17-jre
ENV MYVD_VERSION=1.0.9

HEALTHCHECK CMD pidof java > /dev/null || exit 1

EXPOSE 10983

VOLUME /etc/myvd

ADD entrypoint.sh /opt/entrypoint.sh

RUN	apk add --no-cache $JRE_VERSION bash; \
	cd /opt && wget https://portal.apps.tremolo.io/dwn/tremolosecurity-downloads/myvd/${MYVD_VERSION}/myvd-server-${MYVD_VERSION}.tar.gz; \
	tar -xf myvd-server-${MYVD_VERSION}.tar.gz && rm -rf myvd-server-${MYVD_VERSION}.tar.gz; \
	ln -s myvd-server-${MYVD_VERSION} myvd; \
	cd /opt/myvd/bin && chmod 644 * && chmod 755 myvd.sh runserver.sh && cd /opt; \
	cd /opt/myvd && mv conf conf.default; \
	ln -s /etc/myvd /opt/myvd/conf; \
	chmod 755 /opt/entrypoint.sh

ENTRYPOINT /opt/entrypoint.sh

