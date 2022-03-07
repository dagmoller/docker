#!/bin/bash

MEDIATOMB_PORT=${MEDIATOMB_PORT:-50500}
MEDIATOMB_CONFIG=${MEDIATOMB_CONFIG:-config-samsung.xml}

test -f /var/lib/mediatomb/config.xml || cp /etc/mediatomb/config.xml /var/lib/mediatomb/
test -f /var/lib/mediatomb/config-samsung.xml || cp /etc/mediatomb/config-samsung.xml /var/lib/mediatomb/

/usr/bin/mediatomb --home /var/lib/mediatomb --config /var/lib/mediatomb/${MEDIATOMB_CONFIG} --port ${MEDIATOMB_PORT}

