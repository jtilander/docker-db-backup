#!/bin/bash
#set -e
if [ "$DEBUG" == "1" ]; then
	set -xv
fi

exec 1>&2

set -o pipefail

MIN_FILE_SIZE=200
MYDATE=$(date +%Y%m%d-%H%M%S)
FULLPREFIX=${PREFIX}-${DBNAME}-mysql
FILENAME=${FULLPREFIX}-${MYDATE}.sql.gz

if ! docker ps | grep ${CONTAINER} > /dev/null ; then
	echo "[$0] FATAL: Could not find ${CONTAINER} running. No backups will be taken."
	exit 1
fi

echo "Backing up ${DBNAME} from container ${CONTAINER} into ${FILENAME}"
docker exec ${CONTAINER} /usr/bin/mysqldump -u ${USERNAME} --password=${PASSWORD} ${DBNAME} | gzip -c > ${FILENAME}

if [ $? -ne 0 ]; then
	echo "[$0] FATAL: Failed to create backupfile ${FILENAME}"
	exit 1
fi

SIZE=$(ls -l $FILENAME | awk '{ print $5 }')
if ((SIZE<MIN_FILE_SIZE)) ; then 
    echo "[$0] FATAL: Output file ${FILENAME} is too small (${SIZE} was less than min ${MIN_FILE_SIZE}), probably indicates an error."
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
