
FROM alpine:3.16

HEALTHCHECK CMD pidof radiusd > /dev/null || exit 1

ADD entry.sh /entry.sh

RUN apk update && apk add freeradius && chmod 755 /entry.sh

EXPOSE 1812/udp 1813/udp

ENTRYPOINT /entry.sh

