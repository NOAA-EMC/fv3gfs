#!/bin/ksh
# Run under ksh (converted to WCOSS)


# This script performs VAD wind complex quality control checking
#
# It is normally executed by the script prepobs_makeprepbufr.sh
#  but can also be executed from a checkout parent script
# --------------------------------------------------------------

set -aux

qid=$$

# Positional parameters passed in:
#   1 - path to COPY OF input prepbufr file --> becomes output prepbufr
#       file upon successful completion of this script (note that input
#       prepbufr file is NOT saved by this script)
#   2 - ncep production date (YYYYMMDDHH)

# Imported variables that must be passed in:
#   DATA  - path to working directory
#   VQCX  - path to PREPOBS_CQCVAD program executable

# Imported variables that can be passed in:
#   pgmout   - string indicating path to for standard output file (skipped
#              over by this script if not passed in)

cd $DATA
PRPI=$1
if [ ! -s $PRPI ] ; then exit 1;fi
CDATE10=$2

set +x
cat <<\EOFc > cqcvad05
 &NAMLST
   HONOR_FLAGS=TRUE,  ! If TRUE then levels with bad q.m. flags are honored
   PRINT_52=TRUE,     ! If TRUE then writes bird quality control information
                      !  to unit 52
   PRINT_53=FALSE,    ! If TRUE then writes a final report listing with q.c.
                      !  information to unit 53
   PRINT_60=FALSE,    ! If TRUE then writes event information to unit 60
   TEST=FALSE         ! If TRUE then writes diagnostic print to stdout (unit 06)
 /
EOFc
set -x

rm $PRPI.cqcvad

pgm=`basename  $VQCX`
if [ -s $DATA/prep_step ]; then
   set +u
   . $DATA/prep_step
   set -u
else
   [ -f errfile ] && rm errfile
   unset FORT00 `env | grep "^FORT[0-9]\{1,\}=" | awk -F= '{print $1}'`
fi

export FORT11=$PRPI
echo "$CDATE10"      > cdate10.dat
export FORT14=cdate10.dat
export FORT51=$PRPI.cqcvad
export FORT52=cqcvad.birdqc
export FORT53=cqcvad.unit53.wrk
export FORT55=cqcvad.unit55.wrk
export FORT60=cqcvad.unit60.wrk
TIMEIT=${TIMEIT:-""}
[ -s $DATA/time ] && TIMEIT="$DATA/time -p"
$TIMEIT $VQCX < cqcvad05 > outout 2> errfile
err=$?
###cat errfile
cat errfile >> outout
cat outout >> cqcvad.out
set +u
[ -n "$pgmout" ]  &&  cat outout >> $pgmout
set -u
rm outout
set +x
echo
echo 'The foreground exit status for PREPOBS_CQCVAD is ' $err
echo
set -x
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
   mv $PRPI.cqcvad $PRPI
fi

exit 0
