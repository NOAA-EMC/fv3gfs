#! /bin/sh

set -xue

INFILE="$1"
MIN_SIZE="$2"
MIN_AGE="$3"
SLEEP_WAIT="$4"
MAX_WAIT_STEPS="$5"

waits=0
while [[ "$waits" -lt "$MAX_WAIT_STEPS" ]] ; do
    waits=$(( waits + 1 ))
    mtime=$( stat -c %Y "$INFILE" )
    now=$( date +%s )
    age=$(( now - mtime ))
    size=$( stat -c %s "$INFILE" || echo 0 )
    if [[ ! ( "$size" -ge "$MIN_SIZE"  ) ]] ; then
        echo "$INFILE: too small"
    elif [[ ! ( "$age" -ge "$MIN_AGE" ) ]] ; then
        echo "$INFILE: too young."
    else
        echo "$INFILE: ready."
        exit 0
    fi
    echo "$INFILE: still waiting..."
    sleep "$SLEEP_WAIT"
done

echo "$INFILE: timeout."
exit 1
