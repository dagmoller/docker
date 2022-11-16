#!/bin/sh

basepath=$(realpath $(dirname $0))

# source functions
. $basepath/functions

log
log info "## $(date) ##"
log info "## $(slapd -V 2>&1 | head -n 1) ##"
log

# variables & paths
firstRun=0

openldapEtc=/etc/openldap
openldapData=/var/lib/openldap/data
openldapRun=/var/lib/openldap/run
openldapSlapd=/etc/openldap/slapd.d
openldapCerts=/etc/openldap/certs

containerLdapConfDefault=/opt/openldap/ldap.default
containerCertsDefault=/opt/openldap/certs.default
containerCerts=/opt/openldap/certs
containerCertsOK=/opt/openldap/certs.ok

containerCertsSubj="/C=BR/ST=Rio de Janeiro/O=Docker Container/OU=Docker"

export containerCertsOK

test -d $openldapData && chown -R ldap.ldap $openldapData || install -d -o ldap -g ldap -m 0755 $openldapData
test -d $openldapSlapd && chown -R ldap.ldap $openldapSlapd || install -d -o ldap -g ldap -m 0755 $openldapSlapd
test -d $openldapRun && chown -R ldap.ldap $openldapRun || install -d -o ldap -g ldap -m 0755 $openldapRun
test -d $openldapCerts || install -d -o root -g root -m 0755 $openldapCerts

chmod 755 $openldapData
chmod 755 $openldapSlapd
chmod 755 $openldapCerts

if [ -z "$(ls -A $openldapData)" ]; then
	log info "* OpenLDAP first run..."
	firstRun=1
fi

log info "* Processing environment variables..."
export ldapBaseDN="dc=${LDAP_DOMAIN//\./,dc=}"
export ldapDC="${LDAP_DOMAIN%%.*}"
export ldapAdminPassword="$(slappasswd -s "$LDAP_ADMIN_PASSWORD")"
export ldapConfigPassword="$(slappasswd -s "$LDAP_CONFIG_PASSWORD")"
export ldapReadonlyPassword="$(slappasswd -s "$LDAP_READONLY_PASSWORD")"

LDAP_TLS=$(echo "$LDAP_TLS" | tr '[:upper:]' '[:lower:]')
LDAP_REPLICATION=$(echo "$LDAP_REPLICATION" | tr '[:upper:]' '[:lower:]')
if [ "$LDAP_TLS" == "true" ]; then
	log info "* Processing TLS Options..."
	test -d $containerCertsOK && rm -rf $containerCertsOK
	mkdir -p $containerCertsOK

	defaultRootCACert=$containerCertsDefault/default-ca.crt
	defaultRootCAKey=$containerCertsDefault/default-ca.key

	providedCACert=$containerCerts/$LDAP_TLS_CACERT
	providedCAKey=$containerCerts/$LDAP_TLS_CACERT_KEY
	providedCertKey=$containerCerts/$LDAP_TLS_CERT_KEY
	providedCertFile=$containerCerts/$LDAP_TLS_CERT_FILE
	providedDHFile=$containerCerts/$LDAP_TLS_DH_FILE

	export finalCACert=$containerCertsOK/$LDAP_TLS_CACERT
	export finalCAKey=$containerCertsOK/$LDAP_TLS_CACERT_KEY
	export finalCertKey=$containerCertsOK/$LDAP_TLS_CERT_KEY
	export finalCertFile=$containerCertsOK/$LDAP_TLS_CERT_FILE
	export finalDHFile=$containerCertsOK/$LDAP_TLS_DH_FILE

	buildCertPath=$(mktemp -d)

	isCertsOK=0
	certSelfGenerated=0
	test -f $containerCerts/server-certificate-self-generated && certSelfGenerated=1

	# check user provided certs
	if [ $certSelfGenerated -eq 0 ]; then
		if [ -f $providedCACert ] && [ -f $providedCertKey ] && [ -f $providedCertFile ]; then
			log info "  - Using user provided server certificates..."
			cp -rf $providedCACert $finalCACert
			cp -rf $providedCertKey $finalCertKey
			cp -rf $providedCertFile $finalCertFile

			chmod 644 $containerCertsOK/*
			chmod 600 $finalCertKey

			isCertsOK=1
		fi
	fi

	if [ $certSelfGenerated -eq 1 ] || [ $isCertsOK -eq 0 ]; then
		# check user provided ca cert and key
		caCertUseDefault=1
		if [ -f $providedCACert ] && [ -f $providedCAKey ]; then
			log info "  - Using user provided CA certificate and key..."
			cp -rf $providedCACert $finalCACert
			cp -rf $providedCAKey $finalCAKey
			chmod 644 $finalCACert
			chmod 600 $finalCAKey
			caCertUseDefault=0
		else
			log info "  - Using container default CA certificate and key..."
			ln -s $defaultRootCACert $providedCACert &>/dev/null
			ln -s $defaultRootCACert $finalCACert &>/dev/null
		fi

		# generate server certificates
		if [ $caCertUseDefault -eq 1 ]; then
			cp -rf $defaultRootCACert $buildCertPath/$(basename $finalCACert)
			cp -rf $defaultRootCAKey $buildCertPath/$(basename $finalCAKey)
		else
			cp -rf $finalCACert $buildCertPath/
			cp -rf $finalCAKey $buildCertPath/
		fi

		cd $buildCertPath
		export rootCACrt=$(basename $finalCACert)
		export rootCAKey=$(basename $finalCAKey)
		export serverKey=$(basename $finalCertKey)
		export serverCrt=$(basename $finalCertFile)
		export serverCsr=openldap.csr
		export serverExt=openldap.ext
		export serverCN=${LDAP_HOSTNAME:-$(hostname -f)}
		export opensslCnf=openssl.cnf

		cp -rf $containerCertsDefault/$serverExt $buildCertPath/
		cp -rf $containerCertsDefault/$opensslCnf $buildCertPath/

		log info "  - Building key and server signing request certificate..." nw
		mkdir -p ./rootCA/newcerts
		touch ./rootCA/index.txt
		echo 1000 > ./rootCA/serial

		out=$(openssl req -new -sha256 -newkey rsa:2048 -nodes -keyout $serverKey -out $serverCsr \
			-subj "${containerCertsSubj}/CN=${serverCN}" 2>&1)
		test $? -eq 0 && log ok " OK" || log error " Fail: \n$out"

		log info "  - Processing TLS AltNames..."
		tlsIP="IP.1 = 127.0.0.1\nIP.2 = ::1\n"
		tlsDNS="DNS.1 = localhost\nDNS.2 = localhost.localdomain\n"

		idxIP=2
		idxDNS=2
		for addr in $LDAP_TLS_ALTNAMES; do
			isIP=$(echo $addr | grep -E "(([0-9]{1,3}\.){3}[0-9]{1,3})|(([0-9A-F]{1,4}\:){1,7})")
			if [ ! -z "$isIP" ]; then
				idxIP=$(($idxIP + 1))
				tlsIP="${tlsIP}IP.${idxIP} = $addr\n"
			else
				idxDNS=$(($idxDNS + 1))
				tlsDNS="${tlsDNS}DNS.${idxDNS} = $addr\n"
			fi
		done

		if [ "$serverCN" != "$(hostname -f)" ]; then
			idxDNS=$(($idxDNS + 1))
			tlsDNS="${tlsDNS}IP.${idxDNS} = $(hostname -f)\n"
		fi
		if [ "$serverCN" != "$(hostname)" ] && [ "$(hostname)" != "$(hostname -f)" ]; then
			idxDNS=$(($idxDNS + 1))
			tlsDNS="${tlsDNS}DNS.${idxDNS} = $(hostname)\n"
		fi

		# add self address
		addrs=$(hostname -i)
		if [ $? -eq 0 ]; then
			addrs=$(echo "$addrs" | grep -E "(([0-9]{1,3}\.){3}[0-9]{1,3})|(([0-9A-F]{1,4}\:){1,7})")
			for addr in $addrs; do
				idxIP=$(($idxIP + 1))
				tlsIP="${tlsIP}IP.${idxIP} = $addr\n"
			done
		fi

		export altNamesIP=$(echo -e $tlsIP)
		export altNamesDNS=$(echo -e $tlsDNS)
		envsubst < $serverExt > ${serverExt}.ok

		log info "  - Signing Server certificate with our Root CA $LDAP_TLS_CACERT..." nw

		out=$(openssl ca -batch -keyfile $rootCAKey -cert $rootCACrt -in $serverCsr -out $serverCrt -days $((365*10)) \
			-extensions req_ext -extfile ${serverExt}.ok -config $opensslCnf 2>&1)
		test $? -eq 0 && log ok " OK" || log error " Fail: \n$out"

		cp -rf $serverKey $providedCertKey &>/dev/null
		cp -rf $serverCrt $providedCertFile &>/dev/null

		cp -rf $serverKey $finalCertKey
		cp -rf $serverCrt $finalCertFile

		touch $containerCerts/server-certificate-self-generated &>/dev/null
	fi

	if [ -f $providedDHFile ]; then
		log info "  - Using already existing DH params file..."
		cp -rf $providedDHFile $finalDHFile
		chmod 644 $finalDHFile
	else
		log info "  - Building DH Params file..." nw
		out=$(openssl dhparam -out $buildCertPath/$LDAP_TLS_DH_FILE 2048 2>&1)
		test $? -eq 0 && log ok " OK" || log error " Fail: \n$out"

		cp -rf $buildCertPath/$LDAP_TLS_DH_FILE $providedDHFile &>/dev/null
		cp -rf $buildCertPath/$LDAP_TLS_DH_FILE $finalDHFile
	fi

	chown ldap.ldap $containerCertsOK/*

	rm -rf $openldapCerts/*
	ln -s $finalCACert $openldapCerts/
	cd $openldapCerts
	c_rehash . &> /dev/null

	rm -rf $buildCertPath
fi

if [ $firstRun -eq 1 ]; then
	log info "* OpenLDAP first run, bootstrapping database..."

	srcpath=/opt/openldap/ldifs
	dstpath=/tmp/ldifs

	if [ ! -f $srcpath/slapd.ldif ]; then
		log error "  # $srcpath/slapd.ldif no found, cannot bootstrap OpenLDAP database..."
		exit 99
	fi

	mkdir -p $dstpath

	# processing files and variables
	for file in $srcpath/*.ldif; do
		name=$(basename $file)
		envsubst < $file > $dstpath/$name
	done

	# slapd always run first
	log info "  - Processing $dstpath/slapd.ldif..." nw
	out=$(slapadd -d $LDAP_DEBUG_LEVEL -n 0 -F $openldapSlapd -l $dstpath/slapd.ldif 2>&1)
	test $? -eq 0 && log ok " OK" || log error " Fail: \n$out"

	chown -R ldap.ldap $openldapSlapd
	rm -rf $dstpath/slapd.ldif

	log info "  - Starting OpenLDAP for the first time..." nw
	/usr/sbin/slapd -F $openldapSlapd -u ldap -g ldap -h "ldapi:///" &
	sleep 1
	test $? -eq 0 && log ok " OK"

	for file in $dstpath/*.ldif; do
		comm=ldapmodify
		if [ $(echo "$file" | grep -ic "\-add\-") -gt 0 ]; then
			comm=ldapadd
		fi

		if [ $(echo "$file" | grep -ic "tls") -gt 0 ] && [ "$LDAP_TLS" != "true" ]; then
			continue
		fi

		if [ $(echo "$file" | grep -ic "replication") -gt 0 ]; then
			if [ "$LDAP_REPLICATION" == "true" ]; then
				srcfile=/opt/openldap/ldifs/02-modify-replication.ldif
				if [ -f $srcfile ]; then
					dstpath=/tmp/ldifs
					mkdir -p $dstpath

					olcServerID=
					olcSyncreplConfig=""
					olcSyncreplDatabase=""
					idx=1
					for replicationHost in $LDAP_REPLICATION_HOSTS; do
						olcServerID="${olcServerID}olcServerID: ${idx} ${replicationHost}\n"

						sIdx=$(($idx + 100))
						olcSyncreplConfig="${olcSyncreplConfig}olcSyncrepl: rid=${idx} provider=${replicationHost} ${LDAP_REPLICATION_CONFIG_SYNCPROV}\n"
						olcSyncreplDatabase="${olcSyncreplDatabase}olcSyncrepl: rid=${idx} provider=${replicationHost} ${LDAP_REPLICATION_DB_SYNCPROV}\n"

						idx=$(($idx + 1))
					done

					export olcServerID="$(echo -e ${olcServerID::-2})"
					export olcSyncreplConfig="$(echo -e ${olcSyncreplConfig::-2})"
					export olcSyncreplDatabase="$(echo -e ${olcSyncreplDatabase::-2})"

					log info "  - Updating Replication Config..." nw
					envsubst < $srcfile > $dstpath/$(basename $srcfile)
					envsubst < $dstpath/$(basename $srcfile) > $dstpath/$(basename $srcfile).ldif
					out=$(ldapmodify -Q -H ldapi:/// -Y EXTERNAL -f $dstpath/$(basename $srcfile).ldif 2>&1)
					test $? -eq 0 && log ok " OK" || log error " Fail: \n$out"
				fi
			fi
			continue
		fi

		log info "  - Processing $file..." nw
		out=$($comm -Q -H ldapi:/// -Y EXTERNAL -f $file 2>&1)
		test $? -eq 0 && log ok " OK" || log error " Fail: \n$out"
	done

	rm -rf $dstpath
	#sleep 3600

	kill -9 $(pidof slapd)
	sleep 1
else
	# make updates...
	log info "* Starting OpenLDAP in background to make updates..." nw
	/usr/sbin/slapd -F $openldapSlapd -u ldap -g ldap -h "ldapi:/// ldap:///" &
	sleep 1
	test $? -eq 0 && log ok " OK"

	dstpath=/tmp/ldifs
	mkdir -p $dstpath

	# update TLS
	if [ "$LDAP_TLS" == "true" ]; then
		srcfile=/opt/openldap/ldifs/01-modify-tls.ldif
		if [ -f $srcfile ]; then
			log info "  - Updating TLS Certificates..." nw
			envsubst < $srcfile > $dstpath/$(basename $srcfile)
			out=$(ldapmodify -Q -H ldapi:/// -Y EXTERNAL -f $dstpath/$(basename $srcfile) 2>&1)
			test $? -eq 0 && log ok " OK" || log error " Fail: \n$out"
		fi
	fi

	# replication
	if [ "$LDAP_REPLICATION" == "true" ]; then
		srcfile=/opt/openldap/ldifs/02-modify-replication.ldif
		if [ -f $srcfile ]; then
			olcServerID=
			olcSyncreplConfig=""
			olcSyncreplDatabase=""
			idx=1
			for replicationHost in $LDAP_REPLICATION_HOSTS; do
				olcServerID="${olcServerID}olcServerID: ${idx} ${replicationHost}\n"

				sIdx=$(($idx + 100))
				olcSyncreplConfig="${olcSyncreplConfig}olcSyncrepl: rid=${idx} provider=${replicationHost} ${LDAP_REPLICATION_CONFIG_SYNCPROV}\n"
				olcSyncreplDatabase="${olcSyncreplDatabase}olcSyncrepl: rid=${idx} provider=${replicationHost} ${LDAP_REPLICATION_DB_SYNCPROV}\n"

				idx=$(($idx + 1))
			done

			export olcServerID="$(echo -e ${olcServerID::-2})"
			export olcSyncreplConfig="$(echo -e ${olcSyncreplConfig::-2})"
			export olcSyncreplDatabase="$(echo -e ${olcSyncreplDatabase::-2})"

			log info "  - Updating Replication Config..." nw
			envsubst < $srcfile > $dstpath/$(basename $srcfile)
			envsubst < $dstpath/$(basename $srcfile) > $dstpath/$(basename $srcfile).ldif
			out=$(ldapmodify -Q -H ldapi:/// -Y EXTERNAL -f $dstpath/$(basename $srcfile).ldif)
			test $? -eq 0 && log ok " OK" || log error " Fail: \n$out"
		fi
	fi

	rm -rf $dstpath

	kill -9 $(pidof slapd)
	sleep 1
fi

ldapConf=$openldapEtc/ldap.conf
if [ ! -f $ldapConf ]; then
	log info "* Populating $ldapConf"
	envsubst < $containerLdapConfDefault/ldap.conf > $ldapConf

	if [ "$LDAP_TLS" == "true" ]; then
		echo "# TLS Options" >> $ldapConf
		echo "TLS_CACERT $openldapCerts/$LDAP_TLS_CACERT" >> $ldapConf
		echo "TLS_REQCERT $LDAP_TLS_VERIFY_CLIENT" >> $ldapConf
	fi

fi

log info "* Starting OpenLDAP..."
export listenAddress=${LDAP_HOSTNAME:-$(hostname -f)}

test "$LDAP_TLS" == "true" && ldapS="ldaps:///"
/usr/sbin/slapd -d $LDAP_DEBUG_LEVEL $ldapConfigParam -u ldap -g ldap -h "ldap:/// $ldapS ldapi:///"
