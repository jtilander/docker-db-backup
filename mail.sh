#!/bin/bash
# This is the custom mailer script for dcron to ensure that the output from the cron jobs doesn't
# dissapear into some mailbox, but instead wind up in the docker logs.

# The script itself is invoked with stdin < mailFile and stderr > /dev/null
# (see job.c 318 for more info)

# Output everything to top level process' stdout to ensure that docker logs everything. Amazing that this works.
exec >> /proc/1/fd/1
exec 2>&1

if [ "$DEBUG" == "1" ]; then
	set -xv
fi

[ "$DEBUG" == "1" ] && echo "Mailer from cron invoked with $@"

# stdin will be a classic mail header To: + Subject: + blank line. Let's skip these
i=1
while read line
do
        test $i -le 3 && ((i=i+1)) && continue
        echo $line
done < /dev/stdin

exit 0
