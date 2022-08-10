
FROM alpine:3.16

ENV JRE_VERSION=openjdk17-jre
ENV MYVD_VERSION=1.0.16

HEALTHCHECK CMD pidof java > /dev/null || exit 1

EXPOSE 10983

VOLUME /etc/myvd

ADD entrypoint.sh /opt/entrypoint.sh

RUN	apk add --no-cache $JRE_VERSION bash; \
	cd /opt && wget https://portal.apps.tremolo.io/dwn/tremolosecurity-downloads/myvd/${MYVD_VERSION}/myvd-server-${MYVD_VERSION}.tar.gz; \
	tar -xf myvd-server-${MYVD_VERSION}.tar.gz && rm -rf myvd-server-${MYVD_VERSION}.tar.gz; \
	ln -s myvd-server-${MYVD_VERSION} myvd; \
	cd /opt/myvd/bin && chmod 644 * && chmod 755 myvd.sh runserver.sh; \
	cd /opt/myvd/bin && sed -e 's/2>&1 > \/dev\/null &//g' -i myvd.sh; \
	cd /opt/myvd/conf && sed -e 's/<\/RollingFile>/<\/RollingFile>\n\t\t<Console name="server-log">\n\t\t\t<PatternLayout pattern="[%d][%t] %-5p %c{1} - %m%n" \/>\n\t\t<\/Console>/g' -i log4j2.xml; \
	chmod 755 /opt/entrypoint.sh

ENTRYPOINT /opt/entrypoint.sh

