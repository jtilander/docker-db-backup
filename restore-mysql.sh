#!/bin/bash
if [ "$DEBUG" == "1" ]; then
	set -xv
fi

FULLPREFIX=${PREFIX}-${DBNAME}-mysql
FILENAME=$(ls -tp ${FULLPREFIX}-*.sql.gz | grep -v '/$' | head -1)

echo "Restoring ${DBNAME} in container ${CONTAINER} from ${FILENAME}"

cat ${FILENAME} | gunzip -c | docker exec -i ${CONTAINER} /usr/bin/mysql -u ${USERNAME} --password=${PASSWORD} ${DBNAME}

if [ $? -ne 0 ]; then
	echo "Failed to restore ${DBNAME} from ${FILENAME}"
	exit 1
fi

exit 0
