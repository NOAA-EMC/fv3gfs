#!/bin/ksh
# Run under ksh (converted to WCOSS)

# This script performs an oi-based quality control on all data
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
#   2 - NCEP production date (YYYYMMDDHH)

# Imported variables that must be passed in:
#   DATA - path to working directory
#   OIQCT - path to observation error table file
#   OIQCX - path to PREPOBS_OIQCBUFR program executable

# Imported variables that can be passed in:
#   jlogfile - string indicating path to joblog file (skipped over by this
#              script if not passed in)
#   pgmout   - string indicating path to for standard output file (skipped
#              over by this script if not passed in)
#   sys_tp   - system type and phase.  (if not passed in, an attempt is made to
#              set this string using getsystem.pl, an NCO script in prod_util)
#   SITE     - site name (may have been set by local shell startup script)
#   launcher_OIQCX - launcher for OIQCX executable (on Cray-XC40, defaults to
#                    aprun using 16 tasks)

cd $DATA
PRPI=$1
if [ ! -s $PRPI ] ; then exit 1;fi
CDATE10=$2

jlogfile=${jlogfile:=""}

rm $PRPI.oiqcbufr
rm tosslist

pgm=`basename  $OIQCX`
if [ -s $DATA/prep_step ]; then
   set +u
   . $DATA/prep_step
   set -u
else
   [ -f errfile ] && rm errfile
   unset FORT00 `env | grep "^FORT[0-9]\{1,\}=" | awk -F= '{print $1}'`
fi

#### THE BELOW APPLIED TO THE CCS (IBM AIX)  (kept for reference)
#set +u
#[ -n "$LOADL_PROCESSOR_LIST" ] && export XLSMPOPTS=parthds=2:usrthds=2:stack=64000000
#set -u

echo "      $CDATE10" > cdate.dat
export FORT11=cdate.dat
export FORT14=$PRPI
export FORT17=$OIQCT
export FORT18=obprt_ipoint.wrk
export FORT20=tolls.wrk
export FORT61=toss.sfc_z
export FORT62=toss.temp_wind
export FORT63=toss.sat_temp
export FORT64=toss.ssmi_wind
export FORT65=tosslist
export FORT70=$PRPI.oiqcbufr
export FORT81=obogram.out
export FORT82=obogram.bin
TIMEIT=${TIMEIT:-""}
[ -s $DATA/time ] && TIMEIT="$DATA/time -p"
# $TIMEIT mpirun $OIQCX > outout 2> errfile
#$TIMEIT mpirun -genvall -n $LSB_DJOB_NUMPROC -machinefile $LSB_DJOB_HOSTFILE $OIQCX > outout 2> errfile

SITE=${SITE:-""}
sys_tp=${sys_tp:-$(getsystem.pl -tp)}
getsystp_err=$?
if [ $getsystp_err -ne 0 ]; then
   msg="***WARNING: error using getsystem.pl to determine system type and phase"
   [ -n "$jlogfile" ] && $DATA/postmsg "$jlogfile" "$msg"
fi
echo sys_tp is set to: $sys_tp
if [ "$sys_tp" = "Cray-XC40" -o "$SITE" = "SURGE" -o "$SITE" = "LUNA" ]; then
   launcher_OIQCX=${launcher_OIQCX:-"aprun -n 16 -N 16 -j 1"}  # consistent with tide/gyre
#  launcher_OIQCX=${launcher_OIQCX:-"aprun -n 24 -N 24 -j 1"}  # slightly faster
else
   launcher_OIQCX=${launcher_OIQCX:-"mpirun.lsf"}
#########################module load ibmpe ics lsf uncomment if not in profile
#  seems to run ok w next 10 lines commented out (even though Jack had them in
#   his version of this script)
###export LANG=en_US
###export MP_EAGER_LIMIT=65536
###export MP_EUIDEVELOP=min
###export MP_EUIDEVICE=sn_all
###export MP_EUILIB=us
###export MP_MPILIB=mpich2
###export MP_USE_BULK_XFER=yes
###export MPICH_ALLTOALL_THROTTLE=0
###export MP_COLLECTIVE_OFFLOAD=yes
###export KMP_STACKSIZE=1024m
fi

$TIMEIT $launcher_OIQCX $OIQCX > outout  2> errfile

err=$?
###cat errfile
cat errfile >> outout
cat outout >> oiqcbufr.out
cp outout obcnt.out
set +u
[ -n "$pgmout" ]  &&  cat outout >> $pgmout
set -u
rm outout
set +x
echo
echo 'The foreground exit status for PREPOBS_OIQCBUFR is ' $err
echo
set -x
if [ "$err" -eq '4' ]; then
msg="WRNG: SOME OBS NOT QC'd BY PGM PREPOBS_OIQCBUFR - # OF OBS > LIMIT \
--> non-fatal"
   set +x
   echo
   echo "$msg"
   echo
   set -x
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
   mv $PRPI.oiqcbufr $PRPI
fi

exit 0
