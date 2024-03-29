#!/bin/sh

basepath=$(realpath $(dirname $0))

# source functions
. $basepath/functions

log
log info "## $(date) ##"
log info "## $(slapd -VV 2>&1 | head -n 1) ##"
log

# variables & paths
firstRun=0

openldapReady=/tmp/openldap-ready
openldapEtc=/etc/openldap
openldapData=/var/lib/openldap/data
openldapRun=/var/lib/openldap/run
openldapSlapd=/etc/openldap/slapd.d
export openldapCerts=/etc/openldap/certs

containerLdapConfDefault=/opt/openldap/ldap.default
containerCertsDefault=/opt/openldap/certs.default
containerCerts=/opt/openldap/certs
containerCertsOK=/opt/openldap/certs.ok

containerCertsSubj=$LDAP_TLS_CERT_SUBJ

export containerCertsOK

test -d $openldapData && chown -R ldap.ldap $openldapData || install -d -o ldap -g ldap -m 0755 $openldapData
test -d $openldapSlapd && chown -R ldap.ldap $openldapSlapd || install -d -o ldap -g ldap -m 0755 $openldapSlapd
test -d $openldapRun && chown -R ldap.ldap $openldapRun || install -d -o ldap -g ldap -m 0755 $openldapRun
test -d $openldapCerts || install -d -o root -g root -m 0755 $openldapCerts

# clear $openldapRun
rm -rf $openldapReady
rm -rf $openldapRun/*

chmod 755 $openldapData
chmod 755 $openldapSlapd
chmod 755 $openldapCerts

if [ -z "$(ls -A $openldapData)" ]; then
	log info "* OpenLDAP first run..."
	firstRun=1
fi

tlsEnabled=$(getBoolean $LDAP_TLS)
noUpdate=$(getBoolean $LDAP_NOUPDATE)

log info "* Processing environment variables..."
export ldapBaseDN="dc=${LDAP_DOMAIN//\./,dc=}"
export ldapDC="${LDAP_DOMAIN%%.*}"
export ldapAdminPassword="$(slappasswd -s "$LDAP_ADMIN_PASSWORD")"
export ldapConfigPassword="$(slappasswd -s "$LDAP_CONFIG_PASSWORD")"

export ldapReadonlyUser=$LDAP_READONLY_USER
export ldapReadonlyPassword="$(slappasswd -s "$LDAP_READONLY_PASSWORD")"

if [ $tlsEnabled -eq 1 ]; then
	log info "* Processing TLS Options..."
	test -d $containerCertsOK && rm -rf $containerCertsOK
	mkdir -p $containerCertsOK

	defaultRootCACert=$containerCertsDefault/default-ca.crt
	defaultRootCAKey=$containerCertsDefault/default-ca.key

	providedCACert=$containerCerts/$LDAP_TLS_CACERT
	providedCAKey=$containerCerts/$LDAP_TLS_CACERT_KEY
	providedCertKey=$containerCerts/$LDAP_TLS_CERT_KEY
	providedCertFile=$containerCerts/$LDAP_TLS_CERT_FILE
	providedCrlFile=$containerCerts/$LDAP_TLS_CRL_FILE
	providedDHFile=$containerCerts/$LDAP_TLS_DH_FILE

	export finalCACert=$containerCertsOK/$LDAP_TLS_CACERT
	export finalCAKey=$containerCertsOK/$LDAP_TLS_CACERT_KEY
	export finalCertKey=$containerCertsOK/$LDAP_TLS_CERT_KEY
	export finalCertFile=$containerCertsOK/$LDAP_TLS_CERT_FILE
	export finalCrlFile=$containerCertsOK/$LDAP_TLS_CRL_FILE
	export finalDHFile=$containerCertsOK/$LDAP_TLS_DH_FILE

	buildCertPath=$(mktemp -d)

	isCertsOK=0
	certSelfGenerated=0
	test -f $containerCerts/server-certificate-self-generated && certSelfGenerated=1

	# check user provided certs
	if [ $certSelfGenerated -eq 0 ]; then
		if [ -f $providedCACert ] && [ -f $providedCertKey ] && [ -f $providedCertFile ]; then
			log info "  - Using user provided server certificates..."
			cp -f $providedCACert $finalCACert
			cp -f $providedCertKey $finalCertKey
			cp -f $providedCertFile $finalCertFile

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
			cp -f $providedCACert $finalCACert
			cp -f $providedCAKey $finalCAKey
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
			cp -f $defaultRootCACert $buildCertPath/$(basename $finalCACert)
			cp -f $defaultRootCAKey $buildCertPath/$(basename $finalCAKey)
		else
			cp -f $finalCACert $buildCertPath/
			cp -f $finalCAKey $buildCertPath/
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

		cp -f $containerCertsDefault/$serverExt $buildCertPath/
		cp -f $containerCertsDefault/$opensslCnf $buildCertPath/

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

		cp -f $serverKey $providedCertKey &>/dev/null
		cp -f $serverCrt $providedCertFile &>/dev/null

		cp -f $serverKey $finalCertKey
		cp -f $serverCrt $finalCertFile

		touch $containerCerts/server-certificate-self-generated &>/dev/null
	fi

	if [ -f $providedCrlFile ]; then
		log info "  - Using already existing CRL Certificate file..."
		cp -f $providedCrlFile $finalCrlFile
		chmod 644 $finalCrlFile
	fi

	if [ -f $providedDHFile ]; then
		log info "  - Using already existing DH params file..."
		cp -f $providedDHFile $finalDHFile
		chmod 644 $finalDHFile
	else
		log info "  - Building DH Params file..." nw
		out=$(openssl dhparam -out $buildCertPath/$LDAP_TLS_DH_FILE 2048 2>&1)
		test $? -eq 0 && log ok " OK" || log error " Fail: \n$out"

		cp -f $buildCertPath/$LDAP_TLS_DH_FILE $providedDHFile &>/dev/null
		cp -f $buildCertPath/$LDAP_TLS_DH_FILE $finalDHFile
	fi

	chown ldap.ldap $containerCertsOK/*

	rm -rf $openldapCerts/*
	test -f $finalCACert && ln -s $finalCACert $openldapCerts/
	test -f $finalCrlFile && ln -s $finalCrlFile $openldapCerts/
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

	# process schemas
	cp -rf /opt/openldap/schemas/* /etc/openldap/schema/

	if [ $(getBoolean $LDAP_GROUP_MEMBER_SET_MAY) -eq 1 ]; then
		sed '424s/( member $ cn )/cn/' -i /etc/openldap/schema/core.ldif
		sed '425s/businessCategory/member $ businessCategory/' -i /etc/openldap/schema/core.ldif
		sed '476s/( uniqueMember $ cn )/cn/' -i /etc/openldap/schema/core.ldif
		sed '477s/businessCategory/uniqueMember $ businessCategory/' -i /etc/openldap/schema/core.ldif
	fi

	ldapSchemas=""
	for schema in $LDAP_SCHEMAS; do
		ldapSchemas="${ldapSchemas}include: file:///etc/openldap/schema/${schema}.ldif\n"
	done
	export ldapSchemas=$(echo -e "$ldapSchemas")

	# process extras
	for extra in $LDAP_EXTRAS; do
		sed -e "s/#${extra} //g" -i $srcpath/slapd.ldif
	done

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
	/usr/sbin/slapd -u ldap -g ldap -h "ldapi:///"
	test $? -eq 0 && log ok " OK" || log error " Fail"

	for file in $dstpath/*.ldif; do
		comm=ldapmodify
		if [ $(echo "$file" | grep -ic "\-add\-") -gt 0 ]; then
			comm=ldapadd
		fi

		if [ $(echo "$file" | grep -ic "tls") -gt 0 ] && [ "$LDAP_TLS" != "true" ]; then
			continue
		fi

		if [ $(echo "$file" | grep -ic "syncprov-config") -gt 0 ] && [ "$LDAP_REPLICATION_CONFIG" != "true" ]; then
			continue
		fi

		if [ $(echo "$file" | grep -ic "syncprov-db") -gt 0 ] && [ "$LDAP_REPLICATION_DB" != "true" ]; then
			continue
		fi

		if [ $(echo "$file" | grep -ic "add-readonly-user") -gt 0 ] && [ "$ldapReadonlyUser" == "" ]; then
			continue
		fi

		if [ $(echo "$file" | grep -ic "modify-passwords") -gt 0 ]; then
			continue
		fi

		if [ $(echo "$file" | grep -ic "replication") -gt 0 ]; then
			if [ $(echo "$file" | grep -ic "replication-config") -gt 0 ] && [ $(getBoolean $LDAP_REPLICATION_CONFIG) -eq 1 ]; then
				srcfile=/opt/openldap/ldifs/02-modify-replication-config.ldif
				if [ -f $srcfile ]; then
					dstpath=/tmp/ldifs
					mkdir -p $dstpath

					if [ "${LDAP_REPLICATION_CONFIG_SYNCPROV}" == "" ]; then
						continue
					fi

					olcServerID=
					olcSyncreplConfig=""

					idx=1
					for replicationHost in $LDAP_REPLICATION_CONFIG_HOSTS; do
						olcServerID="${olcServerID}olcServerID: ${idx} ${replicationHost}\n"

						sIdx=$(($idx + 100))
						olcSyncreplConfig="${olcSyncreplConfig}olcSyncrepl: rid=${idx} provider=${replicationHost} ${LDAP_REPLICATION_CONFIG_SYNCPROV}\n"

						idx=$(($idx + 1))
					done

					if [ "$olcSyncreplConfig" == "" ]; then
						continue
					fi

					export olcServerID="$(echo -e ${olcServerID::-2})"
					export olcSyncreplConfig="$(echo -e ${olcSyncreplConfig::-2})"

					export olcMirrorModeConfig="FALSE"
					if [ $(getBoolean $LDAP_REPLICATION_CONFIG_MIRROR_MODE) -eq 1 ]; then
						export olcMirrorModeConfig="TRUE"
					fi

					log info "  - Updating Replication for Config..." nw
					envsubst < $srcfile > $dstpath/$(basename $srcfile)
					envsubst < $dstpath/$(basename $srcfile) > $dstpath/$(basename $srcfile).ldif

					out=$(ldapmodify -Q -H ldapi:/// -Y EXTERNAL -f $dstpath/$(basename $srcfile).ldif 2>&1)
					test $? -eq 0 && log ok " OK" || log error " Fail: \n$out"
				fi
			fi

			if [ $(echo "$file" | grep -ic "replication-db") -gt 0 ] && [ $(getBoolean $LDAP_REPLICATION_DB) -eq 1 ]; then
				srcfile=/opt/openldap/ldifs/02-modify-replication-db.ldif
				if [ -f $srcfile ]; then
					dstpath=/tmp/ldifs
					mkdir -p $dstpath

					if [ "${LDAP_REPLICATION_DB_SYNCPROV}" == "" ]; then
						continue
					fi

					olcSyncreplDatabase=""

					idx=1
					for replicationHost in $LDAP_REPLICATION_DB_HOSTS; do
						sIdx=$(($idx + 100))
						olcSyncreplDatabase="${olcSyncreplDatabase}olcSyncrepl: rid=${idx} provider=${replicationHost} ${LDAP_REPLICATION_DB_SYNCPROV}\n"

						idx=$(($idx + 1))
					done

					if [ "$olcSyncreplDatabase" == "" ]; then
						continue
					fi

					export olcSyncreplDatabase="$(echo -e ${olcSyncreplDatabase::-2})"

					export olcMirrorModeDatabase="FALSE"
					if [ $(getBoolean $LDAP_REPLICATION_DB_MIRROR_MODE) -eq 1 ]; then
						export olcMirrorModeDatabase="TRUE"
					fi

					log info "  - Updating Replication for Database..." nw
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
	if [ $noUpdate -eq 0 ]; then
		# make updates...
		log info "* Starting OpenLDAP in background to make updates..." nw

		test $tlsEnabled -eq 1 && ldapS="ldaps:///"
		/usr/sbin/slapd -u ldap -g ldap -h "ldap:/// $ldapS ldapi:///"

		st=$?
		test $st -eq 0 && log ok " OK" || log error " Fail: (status: $st)\n"

		dstpath=/tmp/ldifs
		mkdir -p $dstpath

		# update TLS
		if [ $tlsEnabled -eq 1 ]; then
			srcfile=/opt/openldap/ldifs/01-modify-tls.ldif
			if [ -f $srcfile ]; then
				log info "  - Updating TLS Certificates..." nw
				envsubst < $srcfile > $dstpath/$(basename $srcfile)
				out=$(ldapmodify -Q -H ldapi:/// -Y EXTERNAL -f $dstpath/$(basename $srcfile) 2>&1)
				test $? -eq 0 && log ok " OK" || log error " Fail: \n$out"
			fi
		fi

		# replication
		if [ $(getBoolean $LDAP_REPLICATION_CONFIG) -eq 1 ]; then
			srcfile=/opt/openldap/ldifs/02-modify-replication-config.ldif
			if [ -f $srcfile ]; then
				olcServerID=
				olcSyncreplConfig=""

				idx=1
				for replicationHost in $LDAP_REPLICATION_CONFIG_HOSTS; do
					olcServerID="${olcServerID}olcServerID: ${idx} ${replicationHost}\n"

					sIdx=$(($idx + 100))
					olcSyncreplConfig="${olcSyncreplConfig}olcSyncrepl: rid=${idx} provider=${replicationHost} ${LDAP_REPLICATION_CONFIG_SYNCPROV}\n"

					idx=$(($idx + 1))
				done

				export olcServerID="$(echo -e ${olcServerID::-2})"
				export olcSyncreplConfig="$(echo -e ${olcSyncreplConfig::-2})"

				export olcMirrorModeConfig="FALSE"
				if [ $(getBoolean $LDAP_REPLICATION_CONFIG_MIRROR_MODE) -eq 1 ]; then
					export olcMirrorModeConfig="TRUE"
				fi

				log info "  - Updating Replication for Config..." nw
				envsubst < $srcfile > $dstpath/$(basename $srcfile)
				envsubst < $dstpath/$(basename $srcfile) > $dstpath/$(basename $srcfile).ldif

				out=$(ldapmodify -Q -H ldapi:/// -Y EXTERNAL -f $dstpath/$(basename $srcfile).ldif 2>&1)
				test $? -eq 0 && log ok " OK" || log error " Fail: \n$out"
			fi
		fi

		if [ $(getBoolean $LDAP_REPLICATION_DB) -eq 1 ]; then
			srcfile=/opt/openldap/ldifs/02-modify-replication-db.ldif
			if [ -f $srcfile ]; then
				olcSyncreplDatabase=""

				idx=1
				for replicationHost in $LDAP_REPLICATION_DB_HOSTS; do
					sIdx=$(($idx + 100))
					olcSyncreplDatabase="${olcSyncreplDatabase}olcSyncrepl: rid=${idx} provider=${replicationHost} ${LDAP_REPLICATION_DB_SYNCPROV}\n"

					idx=$(($idx + 1))
				done

				export olcSyncreplDatabase="$(echo -e ${olcSyncreplDatabase::-2})"

				export olcMirrorModeDatabase="FALSE"
				if [ $(getBoolean $LDAP_REPLICATION_DB_MIRROR_MODE) -eq 1 ]; then
					export olcMirrorModeDatabase="TRUE"
				fi

				log info "  - Updating Replication for Database..." nw
				envsubst < $srcfile > $dstpath/$(basename $srcfile)
				envsubst < $dstpath/$(basename $srcfile) > $dstpath/$(basename $srcfile).ldif

				out=$(ldapmodify -Q -H ldapi:/// -Y EXTERNAL -f $dstpath/$(basename $srcfile).ldif 2>&1)
				test $? -eq 0 && log ok " OK" || log error " Fail: \n$out"
			fi
		fi

		# update passwords
		srcfile=/opt/openldap/ldifs/05-modify-passwords.ldif
		if [ -f $srcfile ]; then
			log info "  - Updating Passwords..." nw
			for i in $(seq 0 25); do
				envsubst < $srcfile > $dstpath/$(basename $srcfile)
				if [ "$ldapReadonlyUser" != "" ]; then
					sed -e 's/#READONLY_USER //g' -i $dstpath/$(basename $srcfile)
				fi
				out=$(ldapmodify -Q -H ldapi:/// -Y EXTERNAL -f $dstpath/$(basename $srcfile) 2>&1)
				ret=$?
				test $ret -eq 0 && break || sleep 0.5
			done
			test $ret -eq 0 && log ok " OK" || log error " Fail: \n$out"
		fi

		rm -rf $dstpath

		kill -9 $(pidof slapd)
		sleep 1
	fi
fi
rm -rf $openldapRun/*

echo 1 > $openldapReady

ldapConf=$openldapEtc/ldap.conf
if [ ! -f $ldapConf ]; then
	log info "* Populating $ldapConf"
	envsubst < $containerLdapConfDefault/ldap.conf > $ldapConf

	if [ $tlsEnabled -eq 1 ]; then
		echo "# TLS Options" >> $ldapConf
		echo "TLS_CACERT $openldapCerts/$LDAP_TLS_CACERT" >> $ldapConf
		echo "TLS_REQCERT $LDAP_TLS_VERIFY_CLIENT" >> $ldapConf
	fi
fi

log info "* Starting OpenLDAP..."
log

test $tlsEnabled -eq 1 && ldapS="ldaps:///"
/usr/sbin/slapd -d $LDAP_DEBUG_LEVEL -u ldap -g ldap -h "ldap:/// $ldapS ldapi:///"

lockfile=/tmp/openldap-maintenance-mode.lock
if [ -f $lockfile ]; then
	log
	log warning "## Entering in Maintenance Mode ##"
	log
	sleep 3600
fi
