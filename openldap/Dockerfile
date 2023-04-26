
# Generate default-ca.crt
# cd ./openldap/certs.default
# openssl genrsa -out default-ca.key 2048
# openssl req -x509 -new -nodes -key default-ca.key -sha256 -days $((100*365)) -out default-ca.crt -subj "/C=BR/ST=Rio de Janeiro/O=Docker Container/OU=Docker/CN=docker"

#
# Alpine 3.14 + OpenLDAP 2.4.58
# Alpine 3.17 + OpenLDAP 2.6.3
#

ARG AlpineVersion=3.14

FROM alpine:${AlpineVersion}

ARG ContainerVersion=1.0.1

ADD openldap /opt/openldap

ENV LDAP_DEBUG_LEVEL=256 \
	LDAP_DOMAIN="example.org" \
	LDAP_ORGANIZATION="Example Corp." \
	LDAP_ADMIN_PASSWORD="admin" \
	LDAP_CONFIG_PASSWORD="config" \
	LDAP_READONLY_PASSWORD="readonly" \
	LDAP_SCHEMAS="core cosine inetorgperson nis" \
	LDAP_EXTRAS="memberof refint" \
	LDAP_IDLE_TIMEOUT="0" \
	LDAP_WRITE_TIMEOUT="0" \
	LDAP_THREADS="" \
	\
	LDAP_TLS="true" \
	LDAP_TLS_CACERT="default-ca.crt" \
	LDAP_TLS_CACERT_KEY="default-ca.key" \
	LDAP_TLS_CERT_FILE="openldap.crt" \
	LDAP_TLS_CERT_KEY="openldap.key" \
	LDAP_TLS_CRL_FILE="openldap.crl" \
	LDAP_TLS_DH_FILE="dhparams.pem" \
	LDAP_TLS_CRL_CHECK="all" \
	LDAP_TLS_VERIFY_CLIENT="try" \
	LDAP_TLS_CERT_SUBJ="/C=BR/ST=Rio de Janeiro/O=Docker Container/OU=Docker" \
	LDAP_TLS_ALTNAMES="" \
	\
	LDAP_REPLICATION="false" \
	LDAP_REPLICATION_CONFIG_SYNCPROV="binddn=\"cn=admin,cn=config\" bindmethod=simple credentials=\${LDAP_CONFIG_PASSWORD} searchbase=\"cn=config\" type=refreshAndPersist retry=\"60 +\" timeout=1 starttls=yes tls_reqcert=try" \
	LDAP_REPLICATION_CONFIG_MIRROR_MODE="false" \
	LDAP_REPLICATION_DB_SYNCPROV="binddn=\"cn=admin,\${ldapBaseDN}\" bindmethod=simple credentials=\${LDAP_ADMIN_PASSWORD} searchbase=\"\${ldapBaseDN}\" type=refreshAndPersist interval=00:00:00:10 retry=\"60 +\" timeout=1 starttls=yes tls_reqcert=try" \
	LDAP_REPLICATION_DB_MIRROR_MODE="false" \
	LDAP_REPLICATION_HOSTS=""

RUN apk update; \
	apk add --no-cache gettext openssl ca-certificates \
		openldap openldap-clients openldap-backend-all openldap-overlay-all \
		openldap-passwd-argon2 openldap-passwd-pbkdf2 openldap-passwd-sha2 \
		krb5-server-ldap \
		cyrus-sasl cyrus-sasl-crammd5 cyrus-sasl-digestmd5 cyrus-sasl-gs2 cyrus-sasl-gssapiv2 \
		cyrus-sasl-login cyrus-sasl-ntlm cyrus-sasl-openrc cyrus-sasl-scram cyrus-sasl-static; \
	rm -rf /var/cache/apk; \
	\
	rm -rf /var/lib/openldap/openldap-data; \
	cd /etc/openldap; rm -rf ldap.conf slapd.conf slapd.ldif; \
	\
	chmod 755 /opt/openldap/maintenance.sh; \
	chmod 755 /opt/openldap/entrypoint.sh

EXPOSE 389 636

ENTRYPOINT "/opt/openldap/entrypoint.sh"
