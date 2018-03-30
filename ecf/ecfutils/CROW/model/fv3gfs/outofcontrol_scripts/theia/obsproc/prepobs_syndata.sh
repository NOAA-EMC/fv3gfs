#!/bin/ksh
# Run under ksh (converted to WCOSS)


# This script has two functions:
#  1) Generates synthetic cyclone bogus near tropical storms and appends them
#     to a PREPBUFR file (based on script variable DO_BOGUS).  If may also,
#     based on user-requested switch, flag mass pressure reports "near"
#     tropical storms.
#  2) Flag dropwinsonde wind reports "near" tropical storms (based on user-
#     requested switch).
#
#  Note: It can do both 1 and 2 above or just one of them without the other.
#   
#  (NOTE: SYNDATA is currently restricted to run with T126 gaussian
#         land-sea mask)
#
# It is normally executed by the script prepobs_makeprepbufr.sh
#  but can also be executed from a checkout parent script
# -------------------------------------------------------------

set -aux

# Positional parameters passed in:
#   1 - path to COPY OF input prepbufr file --> becomes output prepbufr
#       file upon successful completion of this script (note that input
#       prepbufr file is NOT saved by this script)
#   2 - path to COPY OF input tcvitals file
#   3 - expected center date in PREPBUFR file (YYYYMMDDHH)


# Imported variables that must be passed in:
#   DATA  - path to working directory
#   SGES  - path to COPY OF global simga first guess file 1 (valid at
#            either center date of PREPBUFR file or nearest cycle time prior
#            to center date of PREPBUFR file which is a multiple of 3)
#   SGESA - path to COPY OF global simga first guess file 2 (either
#            null if SGES is valid at center date of PREPBUFR file or valid
#            at nearest cycle time after center date of PREPBUFR file which
#            is a multiple of 3 if SGES is valid at nearest cycle time
#            prior to center date of PREPBUFR file which is a multiple of 3)
#   PRVT  - path to observation error table file
#   FIXSYND - path to synthethic data fixed field files
#   SYNDX   - path to SYNDAT_SYNDATA program executable
#   SYNDC   - path to SYNDAT_SYNDATA program parm cards

# Imported variables that can be passed in:
#   DO_BOGUS - Generate synthetic cyclone bogus near tropical storms and
#              append them to a PREPBUFR file (and also, based on user-
#              requested switch, flag mass pressure reports "near" tropical
#              storms)?  (choices are "YES" or "NO", anything else defaults to
#              "YES", including if this is not passed in)
#   jlogfile - string indicating path to joblog file (skipped over by this
#              script if not passed in)
#   pgmout   - string indicating path to for standard output file (skipped
#              over by this script if not passed in)
#   sys_tp   - system type and phase.  (if not passed in, an attempt is made to
#              set this string using getsystem.pl, an NCO script in prod_util)
#   SITE     - site name (may have been set by local shell startup script)
#   launcher_SYNDX - launcher for SYNDX executable (on Cray-XC40, defaults to
#                    aprun using single task)


cd $DATA
PRPI=$1
if [ ! -s $PRPI ] ; then exit 1 ;fi
VITL=$2
CDATE10=$3

jlogfile=${jlogfile:=""}

if [ ! -s $VITL ] ; then
   msg="TCVITALS EMPTY - NO PROCESSING PERFORMED BY SYNDAT_SYNDATA for \
$CDATE10  --> non-fatal"
   set +x
   echo
   echo "$msg"
   echo
   set -x
   [ -n "$jlogfile" ] && $DATA/postmsg "$jlogfile" "$msg"

   exit
fi

if [ $DO_BOGUS = 'YES' ]; then
   suffix_char=""
else
   suffix_char="_nobog"
fi

rm -f $PRPI.syndata bogdomn.wrk${suffix_char} alldat${suffix_char}
rm -f stmtrk.wrk${suffix_char} rawdat.wrk${suffix_char} dumcoef${suffix_char}
rm -f matcoef${suffix_char} dthistry${suffix_char} bogrept${suffix_char}
rm -f bogdata${suffix_char} fenvdta.wrk${suffix_char} stkdatb.wrk${suffix_char}
rm -f gesvit${suffix_char} bghistry.diag${suffix_char}
rm -f prevents.filtering.syndata${suffix_char}

pgm=`basename  $SYNDX`
if [ -s $DATA/prep_step ]; then
   set +u
   . $DATA/prep_step
   set -u
else
   [ -f errfile ] && rm errfile
   unset FORT00 `env | grep "^FORT[0-9]\{1,\}=" | awk -F= '{print $1}'`
fi

export FORT11=$VITL
echo "      $CDATE10" > cdate10.dat
export FORT13=cdate10.dat
export FORT14=$FIXSYND/syndat_syndata.slmask.t126.gaussian
export FORT15=bogdomn.wrk${suffix_char}
export FORT16=stmtrk.wrk${suffix_char}
export FORT17=rawdat.wrk${suffix_char}
export FORT19=bghistry.diag${suffix_char}
export FORT21=gesvit${suffix_char}
export FORT22=stkdatb.wrk${suffix_char}
export FORT23=fenvdta.wrk${suffix_char}
export FORT24=bogdata${suffix_char}
export FORT25=$PRPI
#####export FORT30=$SGES
#####export FORT31=$SGESA

# The SYNDAT_SYNDATA code will soon, or may now, open GFS spectral coefficient
# guess files using sigio routines (via W3EMC routine GBLEVENTS) via explicit
# open(unit=number,file=filename) statements.  This conflicts with the FORTxx
# statements above.  One can either remove the explicit open statements in the
# code or replace the above FORTxx lines with soft links.  The soft link
# approach is taken below.

ln -sf $SGES              fort.30
ln -sf $SGESA             fort.31
export FORT32=$PRVT
export FORT40=$FIXSYND/syndat_weight
export FORT58=bogrept${suffix_char}
export FORT59=dthistry${suffix_char}
export FORT61=$PRPI.syndata
export FORT70=matcoef${suffix_char}
export FORT71=dumcoef${suffix_char}
export FORT72=rawdat.wrk${suffix_char}
export FORT73=stmtrk.wrk${suffix_char}
export FORT74=alldat${suffix_char}
export FORT80=prevents.filtering.syndata${suffix_char}
export FORT89=bogdomn.wrk${suffix_char}

#### THE BELOW APPLIED TO THE CCS (IBM AIX)  (kept for reference)
##The choice in the first  line below MAY cause a failure
##The choice in the second line below works!
#set +u
#####[ -n "$LOADL_PROCESSOR_LIST" ] && export XLSMPOPTS=parthds=2:stack=64000000
#[ -n "$LOADL_PROCESSOR_LIST" ] && export XLSMPOPTS=parthds=2:stack=20000000
#set -u

TIMEIT=${TIMEIT:-""}
[ -s $DATA/time ] && TIMEIT="$DATA/time -p"

SITE=${SITE:-""}
sys_tp=${sys_tp:-$(getsystem.pl -tp)}
getsystp_err=$?
if [ $getsystp_err -ne 0 ]; then
   msg="***WARNING: error using getsystem.pl to determine system type and phase"
   [ -n "$jlogfile" ] && $DATA/postmsg "$jlogfile" "$msg"
fi
echo sys_tp is set to: $sys_tp
if [ "$sys_tp" = "Cray-XC40" -o "$SITE" = "SURGE" -o "$SITE" = "LUNA" ]; then
  launcher_SYNDX=${launcher_SYNDX:-"aprun -n 1 -N 1 -d 1"}
else
  launcher_SYNDX=${launcher_SYNDX:-""}
fi
$TIMEIT $launcher_SYNDX $SYNDX < $SYNDC > outout  2> errfile
err=$?
###cat errfile
cat errfile >> outout
[ $DO_BOGUS = 'YES' ]  &&  cat prevents.filtering.syndata >> outout
cat outout >> syndata.out
set +u
[ -n "$pgmout" ]  &&  cat outout >> $pgmout
set -u
rm outout
set +x
echo
echo 'The foreground exit status for SYNDAT_SYNDATA is ' $err
echo
set -x
if [ $err -eq 0 ]; then

   set +x
   echo " --------------------------------------------- "
   echo " ********** COMPLETED PROGRAM $pgm  **********"
   echo " --------------------------------------------- "
   set -x
   msg="$pgm completed normally for $CDATE10 - DO_BOGUS= $DO_BOGUS"
   [ -n "$jlogfile" ] && $DATA/postmsg "$jlogfile" "$msg"
   mv $PRPI.syndata $PRPI

else

msg="SYNDAT_SYNDATA TERMINATED ABNORMALLY WITH CONDITION CODE $err \
--> non-fatal"
   set +x
   echo
   echo "$msg"
   echo
   set -x
   [ -n "$jlogfile" ] && $DATA/postmsg "$jlogfile" "$msg"

fi

exit 0
