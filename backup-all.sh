#!/bin/bash
# This script goes through all the containers, and then issues backups for each one of the databases
# that are found.
set -e

if [ "$DEBUG" == "1" ]; then
	set -xv
fi

exec 1>&2

set -o pipefail

if curl -SsL http://rancher-metadata.rancher.internal/latest/self/host/hostname > /dev/null 2>&1; then
	echo "Detecting rancher metadata, getting the hostname from Rancher..."
	export HOSTNAME=`curl -SsL http://rancher-metadata.rancher.internal/latest/self/host/hostname`
fi

echo "Backing up all database containers on host $HOSTNAME"

( /app/backup-all.py "$1" )

exit 0
