#!/bin/bash
#set -e
if [ "$DEBUG" == "1" ]; then
	set -xv
fi

exec 1>&2

set -o pipefail

MYDATE=$(date +%Y%m%d-%H%M%S)
FULLPREFIX=${PREFIX}-psql
FILENAME=${FULLPREFIX}-${MYDATE}.sql.gz

if ! docker ps | grep ${CONTAINER} > /dev/null ; then
	echo "[$0] FATAL: Could not find ${CONTAINER} running. No backups will be taken."
	exit 1
fi

echo "Backing up all databases from container ${CONTAINER} into ${FILENAME}"
docker exec -t ${CONTAINER} /bin/bash -c "export PGPASSWORD=${PASSWORD} && pg_dumpall -c -U ${USERNAME}" | gzip -c > ${FILENAME}

if [ $? -ne 0 ]; then
	echo "[$0] FATAL: Failed to create backupfile ${FILENAME}"
	exit 1
fi


CANDIDATES=$(ls -tp ${FULLPREFIX}-*.sql.gz | grep -v '/$' | tail -n +$((HISTORY+1)))
if [ -z $CANDIDATES ]; then
	exit 0
fi

[ "$DEBUG" == "1" ] && echo "Only keeping the ${HISTORY} most recent backups"
echo "About to delete the following: $CANDIDATES"

ls -tp ${FULLPREFIX}-*.sql.gz | grep -v '/$' | tail -n +$((HISTORY+1)) | xargs -I {} rm -- {}

exit 0
