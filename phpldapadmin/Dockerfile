
#
# Alpine 3.16 + PHPLdapAdmin 1.2.6.4-r0
# Alpine 3.17 + PHPLdapAdmin 1.2.6.6-r0
#

ARG AlpineVersion=3.17

FROM alpine:${AlpineVersion}

ARG ContainerVersion=1.0.1

ADD phpldapadmin /opt/phpldapadmin

ENV LDAPADMIN_TIMEZONE="" \
	LDAPADMIN_SERVER_NAME="My LDAP Server" \
	LDAPADMIN_SERVER_ADDRESS="" \
	LDAPADMIN_SERVER_PORT="389" \
	LDAPADMIN_BASEDN="" \
	LDAPADMIN_AUTH_TYPE="session" \
	LDAPADMIN_MIN_UIDNUMBER="1000" \
	LDAPADMIN_MIN_GIDNUMBER="500" \
	LDAPADMIN_DISABLE_DSAIT="false" \
	LDAPADMIN_EXTRA_CONFIGS="" \
	\
	LDAPADMIN_TLS_SERVER_CACERT="" \
	LDAPADMIN_TLS_CERT_FILE="nginx.crt" \
	LDAPADMIN_TLS_CERT_KEY="nginx.key" \
	LDAPADMIN_TLS_CERT_SUBJ="/C=BR/ST=Rio de Janeiro/O=Docker Container/OU=Docker"

HEALTHCHECK CMD pidof php-fpm81 &>/dev/null && pidof nginx &>/dev/null || exit 1

RUN apk update; \
	apk add --no-cache gettext openssl ca-certificates phpldapadmin php-fpm nginx; \
	rm -rf /var/cache/apk/*; \
	\
	sed -e 's/user nginx;/user nginx;\ndaemon off;/g' -i /etc/nginx/nginx.conf; \
	sed -e 's/error_log.*/error_log \/dev\/stdout warn;/g' -i /etc/nginx/nginx.conf; \
	sed -e 's/access_log.*/access_log \/dev\/stdout main;/g' -i /etc/nginx/nginx.conf; \
	rm -rf /etc/nginx/http.d/default.conf; \
	\
	sed -e 's/^memory_limit.*/memory_limit = 256M/g' -i /etc/php81/php.ini; \
	sed -e 's/^listen.*/listen = \/var\/run\/php-fpm.sock/g' -i /etc/php81/php-fpm.d/www.conf; \
	sed -e 's/;listen.owner.*/listen.owner = nginx/g' -i /etc/php81/php-fpm.d/www.conf; \
	sed -e 's/;listen.group.*/listen.group = nginx/g' -i /etc/php81/php-fpm.d/www.conf; \
	\
	chmod 755 /opt/phpldapadmin/entrypoint.sh

EXPOSE 80 443

ENTRYPOINT ["/opt/phpldapadmin/entrypoint.sh"]
