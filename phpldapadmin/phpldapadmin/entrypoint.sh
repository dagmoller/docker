#!/bin/sh

basepath=$(realpath $(dirname $0))
phpfpm=php-fpm81

# source functions
. $basepath/functions

log
log info "## $(date) ##"
log info "## $(apk list 2>&1 | grep phpldapadmin | sed -e 's/\[installed\]//g') ##"
log

# variables & paths
firstRun=0

basepath=/opt/phpldapadmin
certpath=$basepath/certs
nginxcertpath=/etc/nginx/certs

# certificates
log info "* Processing TLS Options..."
test -d $nginxcertpath && rm -rf $nginxcertpath/* || mkdir $nginxcertpath

serverCA=$certpath/$LDAPADMIN_TLS_SERVER_CACERT
certfile=$certpath/$LDAPADMIN_TLS_CERT_FILE
certkey=$certpath/$LDAPADMIN_TLS_CERT_KEY

if [ -f $certpath ] && [ -f $certkey ]; then
	log info "  - Using user provided certificates..."
	cp -f $certfile $certkey $nginxcertpath/
else
	log info "  - Using self generated certificates..."
	cd $nginxcertpath

	log info "  - Building certificate and key..." nw
	out=$(openssl req -new -x509 -nodes -days $((365*10)) -out $LDAPADMIN_TLS_CERT_FILE -keyout $LDAPADMIN_TLS_CERT_KEY \
		-subj "${LDAPADMIN_TLS_CERT_SUBJ}" 2>&1)
	test $? -eq 0 && log ok " OK" || log error " Fail: \n$out"
fi

export userTLS=0
if [ -f $serverCA ]; then
	mkdir -p /etc/openldap/certs
	cp -f $serverCA /etc/openldap/certs/
	cd /etc/openldap/certs
	c_rehash . &> /dev/null

	export userTLS=1
fi

# nginx
log info "* Configuring nginx..."
envsubst '${LDAPADMIN_TLS_CERT_FILE},${LDAPADMIN_TLS_CERT_KEY}' < $basepath/nginx/phpldapadmin.conf > /etc/nginx/http.d/phpldapadmin.conf

# phpldapadmin
log info "* Processing phpLDAPAdmin options..."
if [ -f $basepath/config/config.php ]; then
	log info "  - Using user provided phpLDAPAdmin config..."
	cp -f $basepath/config/config.php /etc/phpldapadmin/config.php
else
	test -z "$LDAPADMIN_TIMEZONE" && export userTimezone=0 || export userTimezone=1
	test -z "$LDAPADMIN_BASEDN" && export userBaseDN=0 || export userBaseDN=1

	envsubst '${userTimezone},${LDAPADMIN_TIMEZONE},${LDAPADMIN_SERVER_NAME},${LDAPADMIN_SERVER_ADDRESS},${LDAPADMIN_SERVER_PORT},${userBaseDN},${LDAPADMIN_BASEDN},${LDAPADMIN_AUTH_TYPE},${userTLS},${LDAPADMIN_MIN_UIDNUMBER},${LDAPADMIN_MIN_GIDNUMBER},${LDAPADMIN_EXTRA_CONFIGS}' < $basepath/config-phpldapadmin.php > /etc/phpldapadmin/config.php
fi

if [ "$(echo $LDAPADMIN_DISABLE_DSAIT | tr '[:upper:]' '[:lower:]')" == "true" ]; then
	log info "  - Disabling ManageDSA It..."
	sed '238s#\(.*\)#//\1#' -i /usr/share/webapps/phpldapadmin/lib/ds_ldap.php
	sed '239s#\(.*\)#//\1#' -i /usr/share/webapps/phpldapadmin/lib/ds_ldap.php
fi

# start services
log info "* Starting php-fpm in background..." nw
out=$($phpfpm)
test $? -eq 0 && log ok " OK" || log error " Fail: \n$out"

log info "* Starting nginx in foreground..."
nginx
