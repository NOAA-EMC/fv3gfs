#!/bin/ksh
# Run under ksh (converted to WCOSS)


# This script encodes the background (first guess) and observational
#  errors into the PREPBUFR reports (interpolated to obs. locations)
#
# It is normally executed by the script prepobs_makeprepbufr.sh
#  but can also be executed from a checkout parent script
# -------------------------------------------------------------

set -aux

qid=$$

# Positional parameters passed in:
#   1 - path to COPY OF input prepbufr file --> becomes output prepbufr
#       file upon successful completion of this script (note that input
#       prepbufr file is NOT saved by this script)
#   2 - expected center date in PREPBUFR file (YYYYMMDDHH)

# Imported variables that must be passed in:
#   DATA  - path to working directory
#   NET   - string indicating system network (either "gfs", "gdas", "cdas",
#            "nam", "rap", "rtma" or "urma")
#            NOTE1: NET is changed to gdas in the parent Job script for the
#                   RUN=gdas1 (was gfs - NET remains gfs for RUN=gfs).
#            NOTE2: This is read from the program PREPOBS_PREVENTS via a call
#                   to system routine "GETENV".
#   SGES  - path to COPY OF global simga first guess file 1 (valid at
#            either center date of PREPBUFR file or nearest cycle time prior
#            to center date of PREPBUFR file which is a multiple of 3)
#   SGESA - path to COPY OF global simga first guess file 2 (either
#            null if SGES is valid at center date of PREPBUFR file or valid
#            at nearest cycle time after center date of PREPBUFR file which
#            is a multiple of 3 if SGES is valid at nearest cycle time
#            prior to center date of PREPBUFR file which is a multiple of 3)
#   PRVT  - path to observation error table file
#   PREX  - path to PREPOBS_PREVENTS program executable
#   PREC  - path to PREPOBS_PREVENTS program parm cards

# Imported variables that can be passed in:
#   pgmout   - string indicating path to for standard output file (skipped
#              over by this script if not passed in)

cd $DATA
PRPI=$1
if [ ! -s $PRPI ] ; then exit 1 ;fi
CDATE10=$2

rm $PRPI.prevents
rm prevents.filtering

pgm=`basename  $PREX`
if [ -s $DATA/prep_step ]; then
   set +u
   . $DATA/prep_step
   set -u
else
   [ -f errfile ] && rm errfile
   unset FORT00 `env | grep "^FORT[0-9]\{1,\}=" | awk -F= '{print $1}'`
fi

echo "      $CDATE10" > cdate10.dat
export FORT11=$PRPI
#####export FORT12=$SGES
#####export FORT13=$SGESA

# The PREPOBS_PREVENTS code will soon, or may now, open GFS spectral
# coefficient guess files using sigio routines (via W3EMC routine GBLEVENTS)
# via explicit open(unit=number,file=filename) statements.  This conflicts with
# the FORTxx statements above.  One can either remove the explicit open
# statements in the code or replace the above FORTxx lines with soft links.
# The soft link approach is taken below.

ln -sf $SGES              fort.12
ln -sf $SGESA             fort.13

export FORT14=$PRVT
export FORT15=cdate10.dat
export FORT51=$PRPI.prevents
export FORT52=prevents.filtering

TIMEIT=${TIMEIT:-""}
[ -s $DATA/time ] && TIMEIT="$DATA/time -p"
$TIMEIT $PREX < $PREC > outout  2> errfile
err=$?
###cat errfile
cat errfile >> outout
cat prevents.filtering >> outout
cat outout >> prevents.out
set +u
[ -n "$pgmout" ]  &&  cat outout >> $pgmout
set -u
rm outout
set +x
echo
echo 'The foreground exit status for PREPOBS_PREVENTS is ' $err
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
   mv $PRPI.prevents $PRPI
fi

exit 0
