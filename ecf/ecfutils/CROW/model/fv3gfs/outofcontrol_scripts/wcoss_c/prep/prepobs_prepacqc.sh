#!/bin/ksh
# Run under ksh (converted to WCOSS)


# This script performs two tasks:
#   1) Execute program PREPOBS_PREPACQC to perform aircraft quality control
#      checking
#   2) Execute program PREPOBS_PREPACPF to append a surface level to profile
#      reports in the PREPBUFR-format aircraft profiles file which is output
#      from PREPOBS_PREPACQC
#  Both tasks are optional in case the executing job wants to perform only one
#  of these two tasks.  The default to to perform both tasks.
#
# This script is normally executed by the script prepobs_makeprepbufr.sh
#  but can also be executed from a checkout parent script
# --------------------------------------------------------------------------

set -aux

qid=$$

# Positional parameters that must always be passed in:
#   1 - path to COPY OF input prepbufr file --> becomes output prepbufr
#       file upon successful completion of this script
#       (note that input prepbufr file is NOT saved by this script)
#       {this can be set to "null" if PROCESS_ACQC != YES (see below), since in
#        this case it is not considered}

# Positional parameters that must be passed in if PROCESS_ACPF = YES (see
#  below):
#   2 - path to adpsfc dump file input to PREPOBS_PREPACPF {normally the same
#       one that was read in to generate the prepbufr file in positional
#       parameter 1 or, if PREPOBS_PREPACQC != YES (see below), the prepbufr
#       file processed by program PREPOBS_PREPACQC which presumably ran some
#       place outside of, and prior to, this script}

# Imported variables that must always be passed in:
#   DATA - path to working directory
#   PROCESS_ACQC - switch controlling whether or not to execute
#                  PREPOBS_PREPACQC
#   PROCESS_ACPF - switch controlling whether or not to execute
#                  PREPOBS_PREPACPF

# Imported variables that must be passed in if PROCESS_ACQC = YES:
#   AQCX - path to PREPOBS_PREPACQC program executable
#   AQCC - path to PREPOBS_PREPACQC program parm cards

# Imported variables that must be passed in if PROCESS_ACQC != YES:
#   acft_profiles - path to prepbufr.acft_profiles file output by program
#                   PREPOBS_PREPACQC (which presumably ran some place outside
#                   of, and prior to, this script)

# Imported variables that must be passed in if PROCESS_ACPF = YES:
#   DICT - path to unsorted METAR station dictionary file
#   APFX - path to PREPOBS_PREPACPF program executable

# Imported variables that can be passed in:
#   jlogfile - string indicating path to joblog file
#              (skipped over by this script if not passed in)
#              (only examined if PROCESS_ACPF = YES)
#   pgmout   - string indicating path to for standard output file
#              (skipped over by this script if not passed in)


cd $DATA

jlogfile=${jlogfile:=""}

if [ $PROCESS_ACQC = YES ]; then
   PRPI=$1
   if [ ! -s $PRPI ] ; then exit 1;fi

   rm $PRPI.prepacqc
   rm prepbufr.acft_profiles

   pgm=`basename  $AQCX`
   if [ -s $DATA/prep_step ]; then
   set +u
      . $DATA/prep_step
   set -u
   else
      [ -f errfile ] && rm errfile
      unset FORT00 `env | grep "^FORT[0-9]\{1,\}=" | awk -F= '{print $1}'`
   fi

   export FORT11=$PRPI
   export FORT41=vvel_info.acft_profiles.txt
   export FORT61=$PRPI.prepacqc
   export FORT62=prepbufr.acft_profiles
   TIMEIT=${TIMEIT:-""}
   [ -s $DATA/time ] && TIMEIT="$DATA/time -p"
   # The following improves performance on Cray-XC40 if $AQCX was
   #    linked to the IOBUF i/o buffering library
   export IOBUF_PARAMS='*.log:verbose,*.txt:verbose,*.sorted:verbose'
   $TIMEIT $AQCX< $AQCC > outout 2> errfile
   err=$?
   err_actual=$err
   unset IOBUF_PARAMS
######cat errfile
   cat errfile >> outout
   cat outout >> prepacqc.out
   set +u
   [ -n "$pgmout" ]  &&  cat outout >> $pgmout
   set -u
   rm outout
   set +x
   echo
   echo 'The foreground exit status for PREPOBS_PREPACQC is ' $err
   echo
   set -x
   if [ $err -eq 4 ]; then
      msg="PREPBUFR DATA SET CONTAINS NO "AIRCAR" OR "AIRCFT" TABLE A MESSAGES  --> non-fatal"
      [ -n "$jlogfile" ] && $DATA/postmsg "$jlogfile" "$msg"
      err=0
   fi
   if [ -s $DATA/err_chk ]; then
      $DATA/err_chk
   else
      if test "$err" -gt '0'
      then
#########kill -9 ${qid} # need a WCOSS alternative to this even tho commented
                        #  out in ops
         exit 55
      fi
   fi

   if [ "$err" -gt '0' ]; then
      exit 9
   elif [ "$err_actual" -gt '0' ]; then
      PROCESS_ACPF=NO
   else
     [ ! -f $PRPI.prepacqc ] && touch $PRPI.prepacqc
      mv $PRPI.prepacqc $PRPI
   fi

else
   cp -p $acft_profiles prepbufr.acft_profiles
fi


if [ $PROCESS_ACPF = YES ]; then
   ADPSFC=$2

   sort -n +0.61 -0.67 $DICT > metar.tbl.lon_sorted

   msg=good
   if [ ! -s $ADPSFC ]; then
      msg="WARNING: PREPOBS_PREPACPF COULD NOT RUN, adpsfc FILE NOT FOUND \
--> non-fatal"
   elif [ ! -s prepbufr.acft_profiles ]; then
      msg="WARNING: PREPOBS_PREPACPF COULD NOT RUN, prepbufr.acft_profiles \
FILE NOT FOUND --> non-fatal"
   elif [ ! -s metar.tbl.lon_sorted ]; then
      msg="WARNING: PREPOBS_PREPACPF COULD NOT RUN, metar.tbl FILE NOT FOUND \
--> non-fatal"
   fi
   if [ "$msg" != 'good' ]; then
      set +x
      echo
      echo "$msg"
      echo
      set -x
      [ -n "$jlogfile" ] && $DATA/postmsg "$jlogfile" "$msg"
      exit 0
   fi

   pgm=`basename  $APFX`
   if [ -s $DATA/prep_step ]; then
      set +u
      . $DATA/prep_step
      set -u
   else
      [ -f errfile ] && rm errfile
      unset FORT00 `env | grep "^FORT[0-9]\{1,\}=" | awk -F= '{print $1}'`
   fi

   export FORT11=metar.tbl.lon_sorted
   export FORT12=$ADPSFC
   export FORT13=prepbufr.acft_profiles
   export FORT51=prepbufr.acft_profiles_sfc
   TIMEIT=${TIMEIT:-""}
   [ -s $DATA/time ] && TIMEIT="$DATA/time -p"
   $TIMEIT $APFX > outout 2> errfile
   err=$?
######cat errfile
   cat errfile >> outout
   cat outout >> prepacpf.out
   set +u
   [ -n "$pgmout" ]  &&  cat outout >> $pgmout
   set -u
   rm outout
   set +x
   echo
   echo 'The foreground exit status for PREPOBS_PREPACPF is ' $err
   echo
   set -x
   if [ $err -gt 0 ]; then
      msg="WARNING: PREPOBS_PREPACPF DID NOT COMPLETE NORMALLY --> non-fatal"
      set +x
      echo
      echo "$msg"
      echo
      set -x
      [ -n "$jlogfile" ] && $DATA/postmsg "$jlogfile" "$msg"
   else
      err=0
      [ -s $DATA/err_chk ]  &&  $DATA/err_chk
   fi
fi

exit 0
