#!/bin/bash

MEDIATOMB_PORT=${MEDIATOMB_PORT:-50500}

if [ ! -f /var/lib/mediatomb/config.xml ]; then
	cp /etc/mediatomb/config.xml /var/lib/mediatomb/config.xml
fi

/usr/bin/mediatomb --home /var/lib/mediatomb --config /var/lib/mediatomb/config.xml --port ${MEDIATOMB_PORT}

