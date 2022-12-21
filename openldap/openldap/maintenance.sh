#!/bin/sh

basepath=$(realpath $(dirname $0))

# source functions
. $basepath/functions

lockfile=/tmp/openldap-maintenance-mode.lock

if [ $(echo "$*" | grep -ic "exit") -gt 0 ]; then
	log
	log info    "## $(date) ##"
	log info    "##   Exiting Maintenance Mode   ##"
	log warning "     Please Restart Container     "
	log
	rm -rf $lockfile
	kill -9 $(pidof sleep)
	exit
fi

log
log info "## $(date) ##"
log info "## Entering in Maintenance Mode ##"
log

log "* Creating lock at $lockfile"
touch $lockfile

log "* Stoping OpenLDAP (slapd)"
kill -9 $(pidof slapd)

log
log warning "- To exit maintenance mode execute:"
log         "  $0 --exit"
log
