#!/bin/ksh
# Run under ksh (converted to WCOSS)


# This script performs rawinsonde upper-air complex quality control checking
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
#   CQCS - path to PREPOBS_CQCBUFR program statbge file
#   CQCX - path to PREPOBS_CQCBUFR program executable
#   CQCC - path to PREPOBS_CQCBUFR program parm cards

# Imported variables that can be passed in:
#   pgmout   - string indicating path to for standard output file
#              (skipped over by this script if not passed in)
#   PRPI_m24 - string indicating path to prepbufr file valid 24-hours previous
#              (only needed if temporal checking is being done)
#              (skipped over by this script if not passed in)
#   PRPI_m12 - string indicating path to prepbufr file valid 12-hours previous
#              (only needed if temporal checking is being done)
#              (skipped over by this script if not passed in)
#   PRPI_p12 - string indicating path to prepbufr file valid 12-hours ahead
#              (only needed if temporal checking is being done)
#              (skipped over by this script if not passed in)
#   PRPI_p24 - string indicating path to prepbufr file valid 24-hours ahead
#              (only needed if temporal checking is being done)
#              (skipped over by this script if not passed in)

cd $DATA
PRPI=$1
if [ ! -s $PRPI ] ; then exit 1 ;fi

cp /dev/null $DATA/prepbufr_m24
cp /dev/null $DATA/prepbufr_m12
cp /dev/null $DATA/prepbufr_p12
cp /dev/null $DATA/prepbufr_p24

set +u
[ -n "$PRPI_m24" ]  && cp $PRPI_m24 prepbufr_m24
[ -n "$PRPI_m12" ]  && cp $PRPI_m12 prepbufr_m12
[ -n "$PRPI_p12" ]  && cp $PRPI_p12 prepbufr_p12
[ -n "$PRPI_p24" ]  && cp $PRPI_p24 prepbufr_p24
set -u

rm $PRPI.cqcbufr
rm cqc_events cqc_stncnt cqc_stnlst

pgm=`basename  $CQCX`
if [ -s $DATA/prep_step ]; then
   set +u
   . $DATA/prep_step
   set -u
else
   [ -f errfile ] && rm errfile
   unset FORT00 `env | grep "^FORT[0-9]\{1,\}=" | awk -F= '{print $1}'`
fi

export FORT4=cqcbufr.unit04.wrk
export FORT12=cqc_events
export FORT14=$PRPI
export FORT15=cqc_stncnt
export FORT16=cqc_stnlst
export FORT17=prepbufr_m24
export FORT18=prepbufr_m12
export FORT19=prepbufr_p12
export FORT20=prepbufr_p24
export FORT22=cqc_wndpbm
export FORT23=$CQCS
export FORT51=$PRPI.cqcbufr
export FORT52=cqc_sdm
export FORT60=cqcbufr.unit60.wrk
export FORT61=cqcbufr.unit61.wrk
export FORT62=cqcbufr.unit62.wrk
export FORT64=cqcbufr.unit64.wrk
export FORT68=cqc_radcor
export FORT80=cqcbufr.unit80.wrk
TIMEIT=${TIMEIT:-""}
[ -s $DATA/time ] && TIMEIT="$DATA/time -p"
# The following improves performance on Cray-XC40 if $CQCX was
#    linked to the IOBUF i/o buffering library
export IOBUF_PARAMS='*wrk:verbose,*cqc_*:verbose'
$TIMEIT $CQCX< $CQCC > outout 2> errfile
err=$?
unset IOBUF_PARAMS
###cat errfile
cat errfile >> outout
cat outout >> cqcbufr.out
set +u
[ -n "$pgmout" ]  &&  cat outout >> $pgmout
set -u
rm outout
set +x
echo
echo 'The foreground exit status for PREPOBS_CQCBUFR is ' $err
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
   mv $PRPI.cqcbufr $PRPI
fi

exit 0
