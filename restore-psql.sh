#!/bin/bash
if [ "$DEBUG" == "1" ]; then
	set -xv
fi

FULLPREFIX=${PREFIX}-psql
FILENAME=$(ls -tp ${FULLPREFIX}-*.sql.gz | grep -v '/$' | head -1)

echo "Restoring all databases in container ${CONTAINER} from ${FILENAME}"

cat ${FILENAME} | gunzip -c | docker exec -i ${CONTAINER} /bin/bash -c "export PGPASSWORD=${PASSWORD} && psql --username=${USERNAME} postgres"

if [ $? -ne 0 ]; then
	echo "Failed to restore from ${FILENAME}"
	exit 1
fi

exit 0
