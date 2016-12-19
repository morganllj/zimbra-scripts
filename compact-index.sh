#!/bin/bash
# When the num of deleted docs are > 50,000, index compaction is recommended
# https://bugzilla.zimbra.com/show_bug.cgi?id=76414
# stsimb Sep 2015
#

printonly=0
log2syslog=0

while getopts "nl" opt; do
    case $opt in
	n)
	    echo "-n used, only printing"
	    printonly=1
	    ;;
	l)
	    echo "-l used, logging to syslog"
	    log2syslog=1
    esac
done

export PATH="/usr/local/bin:/bin:/usr/bin:/usr/local/sbin:/sbin:/usr/sbin"
export PERL5LIB=/opt/zimbra/zimbramon/lib/x86_64-linux-thread-multi:/opt/zimbra/zimbramon/lib
export PERLLIB=/opt/zimbra/zimbramon/lib/x86_64-linux-thread-multi:/opt/zimbra/zimbramon/lib
SCRIPT_NAME=`basename $0`
LOCKFILE="/tmp/${SCRIPT_NAME}.lock"
if [ -f ${LOCKFILE} ]; then
    if [ $log2syslog -ne 0 ]; then
	logger "$0 already running......"
    fi
    echo "Already running..."
    exit 1
fi
    
date >  "${LOCKFILE}"

### REAL START SCRIPT #########################################################

THRESHOLD=50000

input=$(mktemp)
zmprov="/opt/zimbra/bin/zmprov"
zmaccts="/opt/zimbra/bin/zmaccts"

# get all active accounts
$zmaccts | awk '/@.*active/ {print $1}' | sort -u > ${input}

# process all accounts
for acct in $(cat ${input}); do
	echo -n "$(date) ${acct}"

	# getIndexStats
	stats="`$zmprov getIndexStats $acct 2>&1`"

	if [[ $stats =~ "mailbox not found" ]]; then
	    echo " mailbox not found"
	    continue
	elif [[ $stats =~ "ERROR" ]]; then
	    echo -n " $stats"
	    continue
	fi

	echo -n " ${stats//:/ }"

	# compare with threshold
	numDeletedDocs=${stats##*:}
	#	echo -n "${numDeletedDocs} ${THRESHOLD}"
	
	if [ ${numDeletedDocs} -gt ${THRESHOLD} ]; then
		# start compact job
	        echo -n " compact index "
	        if [ $printonly -ne 0 ]; then
		    echo would run compact
		    # $zmprov compactIndexMailbox $acct start
		else
		    echo "would run compact"
		fi
	else
		# skip this account
		echo " skip index compaction."
	fi
done

rm -f "${input}"
### REAL END SCRIPT ###########################################################
### Please do not write below this line.

/bin/rm -f "${LOCKFILE}"
exit $?
