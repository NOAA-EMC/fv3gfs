#!/bin/ksh
# Run under ksh (converted to WCOSS)


# This script performs wind profiler quality control checking
#
# It is normally executed by the script prepobs_makeprepbufr.sh
#  but can also be executed from a checkout parent script
# --------------------------------------------------------------------------

set -aux

qid=$$

# Positional parameters passed in:
#   1 - path to COPY OF input prepbufr file --> becomes output prepbufr
#       file upon successful completion of this script (note that input
#       prepbufr file is NOT saved by this script)

# Imported variables that must be passed in:
#   DATA - path to working directory
#   PQCX - path to PREPOBS_PROFCQC program executable
#   PQCC - path to PREPOBS_PROFCQC program parm cards

# Imported variables that can be passed in:
#   jlogfile - string indicating path to joblog file (skipped over by this
#              script if not passed in)
#   pgmout   - string indicating path to standard output file (skipped
#              over by this script if not passed in)

cd $DATA
PRPI=$1
if [ ! -s $PRPI ] ; then exit 1;fi

jlogfile=${jlogfile:=""}

rm $PRPI.profcqc
rm profcqc.monitor profcqc.events

pgm=`basename  $PQCX`
if [ -s $DATA/prep_step ]; then
   set +u
   . $DATA/prep_step
   set -u
else
   [ -f errfile ] && rm errfile
   unset FORT00 `env | grep "^FORT[0-9]\{1,\}=" | awk -F= '{print $1}'`
fi

export FORT14=$PRPI
export FORT51=$PRPI.profcqc
export FORT52=profcqc.monitor1
export FORT53=profcqc.monitor2
export FORT54=profcqc.events1
export FORT55=profcqc.events2
export FORT61=profcqc.stats1
export FORT62=profcqc.stats2
TIMEIT=${TIMEIT:-""}
[ -s $DATA/time ] && TIMEIT="$DATA/time -p"
$TIMEIT $PQCX< $PQCC > outout 2> errfile
err=$?
###cat errfile
cat errfile >> outout
cat profcqc.events2 >> outout
cat outout >> profcqc.out
set +u
[ -n "$pgmout" ]  &&  cat outout >> $pgmout
set -u
rm outout
set +x
echo
echo 'The foreground exit status for PREPOBS_PROFCQC is ' $err
echo
set -x
if [ $err -eq 4 ]; then
   msg="PREPBUFR DATA SET CONTAINS NO "PROFLR" TABLE A MESSAGES  --> non-fatal"
   [ -n "$jlogfile" ] && $DATA/postmsg "$jlogfile" "$msg"
   err=0
fi
if [ -s $DATA/err_chk ]; then
   $DATA/err_chk
else
   if test "$err" -gt '0'
   then
######kill -9 ${qid} # need a WCOSS alternative to this even tho commented out
                     #  in ops
      exit 55
   fi
fi

if [ "$err" -gt '0' ]; then
   exit 9
else
   mv $PRPI.profcqc $PRPI
fi

exit 0
