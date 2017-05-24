#!/bin/bash
set -e

# Ensure a default value for testing.
if [ -z $CONTAINER ]; then
	CONTAINER=$DBTYPE
fi

case "$1" in 
	backup)
		shift
		[ "$DEBUG" == "1" ] && echo "Running backup"
		exec /bin/bash /app/backup-$DBTYPE.sh
		;;

	restore)
		shift
		[ "$DEBUG" == "1" ] && echo "Running restore"
		exec /bin/bash /app/restore-$DBTYPE.sh
		;;

	cron)
		shift

		if [ "$DEBUG" == "1" ]; then
		cat > /etc/crontabs/root <<EOF
# min	hour	day	month	weekday	command
*/1		*		*	*		*		/bin/bash -c "cd /data && /app/backup-$DBTYPE.sh > /tmp/debug-$$.log"
EOF

			echo "Running cron mode"
			echo "This is the crontab:"

			cat /etc/crontabs/root 


			exec /sbin/tini -- /usr/sbin/crond -d -M /app/mail.sh -s /etc/crontabs -L /dev/fd/1
		fi


		cat > /etc/crontabs/root <<EOF
# min	hour	day	month	weekday	command
$CRONSCHEDULE	/bin/bash -c "cd /data && /app/backup-$DBTYPE.sh > /tmp/debug.log"
EOF

		cat /etc/crontabs/root

		exec /sbin/tini -- /usr/sbin/crond -f -M /app/mail.sh -s /etc/crontabs -L /dev/fd/1
		;;
esac

exec "$@"
