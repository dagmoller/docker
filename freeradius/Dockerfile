
FROM alpine:3.16

HEALTHCHECK CMD pidof radiusd > /dev/null || exit 1

ADD entry.sh /entry.sh

RUN apk update; \
	apk add freeradius-eap freeradius-checkrad freeradius-dhcp freeradius-krb5 \
		freeradius-mssql freeradius-client freeradius-unixodbc freeradius-sqlite freeradius-mysql freeradius-static \
		freeradius-lib freeradius-pam freeradius-ldap freeradius freeradius-postgresql \
		freeradius-redis freeradius-utils freeradius-rest freeradius-sql; \
	for file in dhcp eap krb5 ldap pam redis rest sql; do rm -rf /etc/raddb/mods-enabled/$file; done; \
	chmod 755 /entry.sh; \
	cp -a /etc/raddb /etc/_raddb.default

#RUN apk update; \
#	apk add freeradius freeradius-client; \
#	chmod 755 /entry.sh; \
#	cp -a /etc/raddb /etc/_raddb.default

EXPOSE 1812/udp 1813/udp

ENTRYPOINT /entry.sh

