#!/bin/ksh
################################################################################
#
# Name:  getges.sh            Author:  Mark Iredell
#
# Abstract:
# This script copies the valid global guess file to a given file.
# Alternatively, it writes the name of the guess file to standard output.
# Specify option "-n network" for the job network (default global).
# Other options are gdas, gfs, cdas, mrf, prx, etc.
# Specify option "-e environment" for the job environment (default prod).
# Another option is test.
# Specify option "-f fhour" for the specific forecast hour wanted (default any).
# Specify option "-q" for quiet mode to turn off script messages.
# Specify option "-r resolution" for the resolution wanted (default high).
# Other options are 25464 17042, 12628, low, 6228, namopl, any.
# Specify option "-t filetype" for the filetype wanted from among these choices:
# sigges (default), siggm3, siggm2, siggm1, siggp1, siggp2, siggp3,
# sfcges, sfcgm3, sfcgm2, sfcgm1, sfcgp1, sfcgp2, sfcgp3,
# biascr, satang, satcnt, gesfil
# pgbges, pgiges, pgbgm6, pgigm6, pgbgm3, pgigm3, pgbgp3, pgigp3,
# sigcur, sfccur, pgbcur, pgicur, prepqc, tcvg12, tcvges, tcvitl, 
# enggrb, enggri, icegrb, icegri, snogrb, snogrb_high, snogri, sstgrb, sstgri.
# Specify option "-v valid" for the valid date wanted (default $CDATE).
# Currently, the valid hours specified must be a multiple of 3.
# Either 2-digit or 4-digit years are currently allowed.
# Specify positional argument to be the file to which to copy the guess.
# If missing, the NAME of the guess file is written to standard output.
# A nonzero return code from this script means either the arguments are invalid
# or the guess could not be found; a message is written to standard error in
# this case, but neither a file copy nor a standard output write will be done.
# The file returned is guaranteed to exist and be readable.
# The script uses the utility commands NDATE and NHOUR.
#
# Example 1. Copy the production sigma guess for 1998100100 to the file sges.
#  getges.sh -e prod -t sigges -v 1998100100 sges 
#
# Example 2. Assign the pressure grib guess for the date 1998100121.
#  export CDATE=1998100121
#  export XLFUNIT_12="$(getges.sh -qt pgbges||echo /dev/null)"
#
# Example 3. Get the PRX pgb analysis or the best valid guess at 1998100112.
#  getges -e prx -t pgbcur -v 1998100112 pgbfile
#
# Example 5. Get the 24-hour GFS forecast sigma file valid at 1998100112.
#  getges -t sigcur -v 1998100112 -f 24 -e gfs sigfile
#
# History: 1996 December    Iredell       Initial implementation
#          1997 March       Iredell       Nine new filetypes
#          1997 April       Iredell       Two new filetypes and -f option
#          1997 December    Iredell       Four new filetypes
#          1998 April       Iredell       4-digit year allowed;
#                                         sigges internal date no longer checked
#          1998 May         Iredell       T170L42 defaulted; four new filetypes
#                                         and two filetypes deleted
#          1998 June        Rogers        Nam types added
#          1998 September   Iredell       high is default resolution
#          2000 March       Iredell       Cdas and -n option
#          2000 June        Iredell       Eight new filetypes
#          2002 April       Treadon       T254L64 defaulted; add angle dependent
#                                         bias correction file
#          2003 March       Iredell       GFS network out to 384 hours
#          2003 August      Iredell       Hourly global guesses
#          2005 September   Treadon       Add satellite data count file (satcnt)
#          2006 September   Gayno         Add high-res snow analysis
#          2009 January     Rogers        Added sfluxgrb file
#          2011 April       Rogers        Added GFS pg2ges file
#
################################################################################
#-------------------------------------------------------------------------------
# Set some default parameters.
fhbeg=03                         # hour to begin searching backward for guess
fhinc=03                         # hour to increment backward in search
fhend=384                        # hour to end searching backward for guess

#-------------------------------------------------------------------------------
# Get options and arguments.
netwk=global                     # default network
envir=prod                       # default environment
fhour=any                        # default forecast hour
quiet=NO                         # default quiet mode
resol=high                       # default resolution
typef=sigges                     # default filetype
valid=${CDATE:-'?'}              # default valid date
valid=$CDATE                     # default valid date
err=0
while getopts n:e:f:qr:t:v: opt;do
 case $opt in
  n) netwk="$OPTARG";;
  e) envir="$OPTARG";;
  f) fhour="$OPTARG";;
  q) quiet=YES;;
  r) resol="$OPTARG";;
  t) typef="$OPTARG";;
  v) valid="$OPTARG";;
  \?) err=1;;
 esac
done
shift $(($OPTIND-1))
gfile=$1
if [[ -z $valid ]];then
 echo "$0: either -v option or environment variable CDATE must be set" >&2
elif [[ $# -gt 1 ]];then
 echo "$0: too many positional arguments" >&2
elif [[ $err -ne 0 ]];then
 echo "$0: invalid option" >&2
fi
if [[ $gfile = '?' || $# -gt 1 || $err -ne 0 || -z $valid ||\
      $netwk = '?' || $envir = '?' || $fhour = '?' || $resol = '?' ||\
      $typef = '?' || $valid = '?' ]];then
 echo "Usage: getges.sh [-n network] [-e environment] [-f fhour] [-q] [-r resolution]" >&2
 echo "                 [-t filetype] [-v valid] [gfile]" >&2
 if [[ $netwk = '?' ]];then
  echo "         network choices:" >&2
  echo "           global (default), namopl, gdas, gfs, cdas, etc." >&2
 elif [[ $envir = '?' ]];then
  echo "         environment choices:" >&2
  echo "           prod (default), test, para, dump, prx" >&2
  echo "           (some network values allowed for compatibility)" >&2
 elif [[ $fhour = '?' ]];then
  echo "         fhour is optional specific forecast hour" >&2
 elif [[ $resol = '?' ]];then
  echo "         resolution choices:" >&2
  echo "           high (default), 25464, 17042, 12628, low, 6228, namopl, any" >&2
 elif [[ $typef = '?' ]];then
  echo "         filetype choices:" >&2
  echo "           sigges (default), siggm3, siggm2, siggm1, siggp1, siggp2, siggp3," >&2
  echo "           sfcges, sfcgm3, sfcgm2, sfcgm1, sfcgp1, sfcgp2, sfcgp3," >&2
  echo "           sfgges, sfggp3, biascr, satang, satcnt, gesfil" >&2
  echo "           pgbges, pgiges, pgbgm6, pgigm6, pgbgm3, pgigm3, pgbgp3, pgigp3," >&2
  echo "           sigcur, sfccur, pgbcur, pgicur, prepqc, tcvg12, tcvges, tcvitl," >&2
  echo "           enggrb, enggri, icegrb, icegri, snogrb, snogri, sstgrb, sstgri," >&2
  echo "           pg2cur, pg2ges, restrt" >&2
 elif [[ $valid = '?' ]];then
  echo "         valid is the valid date in yyyymmddhh or yymmddhh form" >&2
  echo "         (default is environmental variable CDATE)" >&2
 elif [[ $gfile = '?' ]];then
  echo "         gfile is the guess file to write" >&2
  echo "         (default is to write the guess file name to stdout)" >&2
 else
  echo "         (Note: set a given option to '?' for more details)" >&2 
 fi
 exit 1
fi
#[[ $quiet = NO ]]&&set -x
if [[ $envir != prod && $envir != test && $envir != para && $envir != dump && $envir != pr? && $envir != dev ]];then
 netwk=$envir
 envir=prod
 echo '************************************************************' >&2
 echo '* CAUTION: Using "-e" is deprecated in this case.          *' >&2
 echo '*          Please use "-n" instead.                        *' >&2       
 echo '************************************************************' >&2
fi
if [[ $netwk = namopl || $resol = namopl ]];then
  netwk=namopl
  typef=restrt
  resol=namopl
fi
[[ $resol = 57464 || $resol = 38264 || $resol = 19064 || $resol = 25464 || $resol = 17042 || $resol = 12628 ]]&&resol=high
[[ $resol = 6228 ]]&&resol=low
resolsuf=""
[[ $resol == *deg ]]&&resolsuf=.$resol
fhbeg=$($NHOUR $valid)
[[ $fhbeg -le 0 ]]&&fhbeg=03
((fhbeg=(10#$fhbeg-1)/3*3+3))
[[ $fhbeg -lt 10 ]]&&fhbeg=0$fhbeg
if [[ $typef = enggrb ]];then
 typef=icegrb
 echo '************************************************************' >&2
 echo '* CAUTION: Using "-t enggrb" is now deprecated.            *' >&2
 echo '*          Please use "-t icegrb".                         *' >&2       
 echo '************************************************************' >&2
elif [[ $typef = enggri ]];then
 typef=icegri
 echo '************************************************************' >&2
 echo '* CAUTION: Using "-t enggri" is now deprecated.            *' >&2
 echo '*          Please use "-t icegri".                         *' >&2       
 echo '************************************************************' >&2
fi

#-------------------------------------------------------------------------------
# Default top level directories.
export GETGES_COM=${GETGES_COM:-${COMROOT}}
export GETGES_NWG=${GETGES_NWG:-${GESROOT}}
export GETGES_GLO=${GETGES_GLO:-/gloptmp}

#-------------------------------------------------------------------------------
# Assemble guess list in descending order from the best guess.
geslist=""
geslist00=""

# GDAS
if [[ $netwk = gdas ]];then
 fhend=12
 case $typef in
  sigges)  geslist='
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.sf$fh'
   ;;
  siggm3) geslist='
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.sf$fhm3'
   ;;
  siggm2) geslist='
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.sf$fhm2'
   ;;
  siggm1) geslist='
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.sf$fhm1'
   ;;
  siggp1) geslist='
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.sf$fhp1'
   ;;
  siggp2) geslist='
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.sf$fhp2'
   ;;
  siggp3) geslist='
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.sf$fhp3'
   ;;
  sfcges) geslist='
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.bf$fh'
   ;;
  sfcgm3) geslist='
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.bf$fhm3'
   ;;
  sfcgm2) geslist='
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.bf$fhm2'
   ;;
  sfcgm1) geslist='
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.bf$fhm1'
   ;;
  sfcgp1) geslist='
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.bf$fhp1'
   ;;
  sfcgp2) geslist='
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.bf$fhp2'
   ;;
  sfcgp3) geslist='
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.bf$fhp3'
   ;;
  biascr) geslist='
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.abias'
   ;;
  biascr_pc) geslist='
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.abias_pc'
   ;;
  biascr_air) geslist='
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.abias_air'
   ;;
  radstat) geslist='
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.radstat'
   ;;
  satang) geslist='
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.satang'
   ;;
  satcnt) geslist='
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.satcnt'
   ;;
  gesfil) geslist='
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.gesfile'
   fhbeg=00
   fhend=00
   ;;
  sfgges)  geslist='
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.sfluxgrbf$fh'
   ;;
  sfggp3)  geslist='
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.sfluxgrbf$fhp3'
   ;;
  pgbges) geslist='
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.pgrbh$fh 
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.pgrbf$fh'
   ;;
  pg2ges) geslist='
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.pgrb2f$fh$resolsuf'
   ;;
  pgiges) geslist='
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.pgrbih$fh 
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.pgrbif$fh'
   ;;
  pgbgm6) geslist='
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.pgrbh$fhm6 
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.pgrbf$fhm6'
   ;;
  pgigm6) geslist='
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.pgrbih$fhm6 
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.pgrbif$fhm6'
   ;;
  pgbgm3) geslist='
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.pgrbh$fhm3 
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.pgrbf$fhm3'
   ;;
  pgigm3) geslist='
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.pgrbih$fhm3 
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.pgrbif$fhm3'
   ;;
  pgbgp3) geslist='
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.pgrbh$fhp3 
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.pgrbf$fhp3'
   ;;
  pgigp3) geslist='
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.pgrbih$fhp3 
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.pgrbif$fhp3'
   ;;
  sigcur) geslist='
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.sf$fh'
   getlist00='
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.sanl'
   fhbeg=00
   ;;
  sfccur) geslist='
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.bf$fh'
   getlist00='
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.sfcanl'
   fhbeg=00
   ;;
  pgbcur) geslist='
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.pgrbh$fh 
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.pgrbf$fh'
   fhbeg=00
   ;;
  pg2cur) geslist='
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.pgrb2f$fh$resolsuf'
   fhbeg=00
   ;;
  pgicur) geslist='
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.pgrbih$fh 
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.pgrbif$fh'
   fhbeg=00
   ;;
  prepqc) geslist='
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.prepbufr'
   fhbeg=00
   fhend=00
   ;;
  tcvg12) geslist='
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.syndata.tcvitals.tm00'
   fhbeg=12
   fhend=12
   ;;
  tcvges) geslist='
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.syndata.tcvitals.tm00'
   fhbeg=06
   fhend=06
   ;;
  tcvitl) geslist='
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.syndata.tcvitals.tm00'
   fhbeg=00
   fhend=00
   ;;
  icegrb) geslist='
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.engicegrb'
   fhbeg=00
   fhinc=06
   ;;
  icegri) geslist='
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.engicegrb.index'
   fhbeg=00
   fhinc=06
   ;;
  snogrb) geslist='
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.snogrb'
   fhbeg=00
   fhinc=06
   ;;
  snogrb_high) geslist='
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.snogrb_t574
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.snogrb_t382'
   fhbeg=00
   fhinc=06
   ;;
  snogrb_382) geslist='
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.snogrb_t382'
   fhbeg=00
   fhinc=06
   ;;
  snogrb_574) geslist='
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.snogrb_t574.1152.576'
   fhbeg=00
   fhinc=06
   ;;
  snogrb_1534) geslist='
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.snogrb_t1534.3072.1536'
   fhbeg=00
   fhinc=06
   ;;
  snogri) geslist='
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.snogrb.index'
   fhbeg=00
   fhinc=06
   ;;
  sstgrb) geslist='
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.sstgrb'
   fhbeg=00
   fhinc=06
   ;;
  sstgri) geslist='
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.sstgrb.index'
   fhbeg=00
   fhinc=06
   ;;
 esac

# CFS-CDAS
elif [[ $netwk = cfs-cdas ]];then
 fhend=12
 case $typef in
  sigges)  geslist='
   $GETGES_COM/cfs/$envir/cdas.$day/cdas1.t${cyc}z.sf$fh'
   ;;
  siggm3) geslist='
   $GETGES_COM/cfs/$envir/cdas.$day/cdas1.t${cyc}z.sf$fhm3'
   ;;
  siggm2) geslist='
   $GETGES_COM/cfs/$envir/cdas.$day/cdas1.t${cyc}z.sf$fhm2'
   ;;
  siggm1) geslist='
   $GETGES_COM/cfs/$envir/cdas.$day/cdas1.t${cyc}z.sf$fhm1'
   ;;
  siggp1) geslist='
   $GETGES_COM/cfs/$envir/cdas.$day/cdas1.t${cyc}z.sf$fhp1'
   ;;
  siggp2) geslist='
   $GETGES_COM/cfs/$envir/cdas.$day/cdas1.t${cyc}z.sf$fhp2'
   ;;
  siggp3) geslist='
   $GETGES_COM/cfs/$envir/cdas.$day/cdas1.t${cyc}z.sf$fhp3'
   ;;
  sfcges) geslist='
   $GETGES_COM/cfs/$envir/cdas.$day/cdas1.t${cyc}z.bf${fh}.LIS
   $GETGES_COM/cfs/$envir/cdas.$day/cdas1.t${cyc}z.bf$fh'
   ;;
  sfcgm3) geslist='
   $GETGES_COM/cfs/$envir/cdas.$day/cdas1.t${cyc}z.bf${fhm3}.LIS
   $GETGES_COM/cfs/$envir/cdas.$day/cdas1.t${cyc}z.bf$fhm3'
   ;;
  sfcgm2) geslist='
   $GETGES_COM/cfs/$envir/cdas.$day/cdas1.t${cyc}z.bf${fhm2}.LIS
   $GETGES_COM/cfs/$envir/cdas.$day/cdas1.t${cyc}z.bf$fhm2'
   ;;
  sfcgm1) geslist='
   $GETGES_COM/cfs/$envir/cdas.$day/cdas1.t${cyc}z.bf${fhm1}.LIS
   $GETGES_COM/cfs/$envir/cdas.$day/cdas1.t${cyc}z.bf$fhm1'
   ;;
  sfcgp1) geslist='
   $GETGES_COM/cfs/$envir/cdas.$day/cdas1.t${cyc}z.bf${fhp1}.LIS
   $GETGES_COM/cfs/$envir/cdas.$day/cdas1.t${cyc}z.bf$fhp1'
   ;;
  sfcgp2) geslist='
   $GETGES_COM/cfs/$envir/cdas.$day/cdas1.t${cyc}z.bf${fhp2}.LIS
   $GETGES_COM/cfs/$envir/cdas.$day/cdas1.t${cyc}z.bf$fhp2'
   ;;
  sfcgp3) geslist='
   $GETGES_COM/cfs/$envir/cdas.$day/cdas1.t${cyc}z.bf${fhp3}.LIS
   $GETGES_COM/cfs/$envir/cdas.$day/cdas1.t${cyc}z.bf$fhp3'
   ;;
  biascr) geslist='
   $GETGES_COM/cfs/$envir/cdas.$day/cdas1.t${cyc}z.abias'
   ;;
  satang) geslist='
   $GETGES_COM/cfs/$envir/cdas.$day/cdas1.t${cyc}z.satang'
   ;;
  satcnt) geslist='
   $GETGES_COM/cfs/$envir/cdas.$day/cdas1.t${cyc}z.satcnt'
   ;;
  gesfil) geslist='
   $GETGES_COM/cfs/$envir/cdas.$day/cdas1.t${cyc}z.gesfile'
   fhbeg=00
   fhend=00
   ;;
  sfgges)  geslist='
   $GETGES_COM/cfs/$envir/cdas.$day/cdas1.t${cyc}z.sfluxgrbf$fh'
   ;;
  sfggp3)  geslist='
   $GETGES_COM/cfs/$envir/cdas.$day/cdas1.t${cyc}z.sfluxgrbf$fhp3'
   ;;
  pgbges) geslist='
   $GETGES_COM/cfs/$envir/cdas.$day/cdas1.t${cyc}z.pgrbh$fh 
   $GETGES_COM/cfs/$envir/cdas.$day/cdas1.t${cyc}z.pgrbf$fh'
   ;;
  pgiges) geslist='
   $GETGES_COM/cfs/$envir/cdas.$day/cdas1.t${cyc}z.pgrbih$fh 
   $GETGES_COM/cfs/$envir/cdas.$day/cdas1.t${cyc}z.pgrbif$fh'
   ;;
  pgbgm6) geslist='
   $GETGES_COM/cfs/$envir/cdas.$day/cdas1.t${cyc}z.pgrbh$fhm6 
   $GETGES_COM/cfs/$envir/cdas.$day/cdas1.t${cyc}z.pgrbf$fhm6'
   ;;
  pgigm6) geslist='
   $GETGES_COM/cfs/$envir/cdas.$day/cdas1.t${cyc}z.pgrbih$fhm6 
   $GETGES_COM/cfs/$envir/cdas.$day/cdas1.t${cyc}z.pgrbif$fhm6'
   ;;
  pgbgm3) geslist='
   $GETGES_COM/cfs/$envir/cdas.$day/cdas1.t${cyc}z.pgrbh$fhm3 
   $GETGES_COM/cfs/$envir/cdas.$day/cdas1.t${cyc}z.pgrbf$fhm3'
   ;;
  pgigm3) geslist='
   $GETGES_COM/cfs/$envir/cdas.$day/cdas1.t${cyc}z.pgrbih$fhm3 
   $GETGES_COM/cfs/$envir/cdas.$day/cdas1.t${cyc}z.pgrbif$fhm3'
   ;;
  pgbgp3) geslist='
   $GETGES_COM/cfs/$envir/cdas.$day/cdas1.t${cyc}z.pgrbh$fhp3 
   $GETGES_COM/cfs/$envir/cdas.$day/cdas1.t${cyc}z.pgrbf$fhp3'
   ;;
  pgigp3) geslist='
   $GETGES_COM/cfs/$envir/cdas.$day/cdas1.t${cyc}z.pgrbih$fhp3 
   $GETGES_COM/cfs/$envir/cdas.$day/cdas1.t${cyc}z.pgrbif$fhp3'
   ;;
  sigcur) geslist='
   $GETGES_COM/cfs/$envir/cdas.$day/cdas1.t${cyc}z.sf$fh'
   getlist00='
   $GETGES_COM/cfs/$envir/cdas.$day/cdas1.t${cyc}z.sanl'
   fhbeg=00
   ;;
  sfccur) geslist='
   $GETGES_COM/cfs/$envir/cdas.$day/cdas1.t${cyc}z.bf$fh'
   getlist00='
   $GETGES_COM/cfs/$envir/cdas.$day/cdas1.t${cyc}z.sfcanl'
   fhbeg=00
   ;;
  pgbcur) geslist='
   $GETGES_COM/cfs/$envir/cdas.$day/cdas1.t${cyc}z.pgrbh$fh 
   $GETGES_COM/cfs/$envir/cdas.$day/cdas1.t${cyc}z.pgrbf$fh'
   fhbeg=00
   ;;
  pgicur) geslist='
   $GETGES_COM/cfs/$envir/cdas.$day/cdas1.t${cyc}z.pgrbih$fh 
   $GETGES_COM/cfs/$envir/cdas.$day/cdas1.t${cyc}z.pgrbif$fh'
   fhbeg=00
   ;;
  prepqc) geslist='
   $GETGES_COM/cfs/$envir/cdas.$day/cdas1.t${cyc}z.prepbufr'
   fhbeg=00
   fhend=00
   ;;
  tcvg12) geslist='
   $GETGES_COM/cfs/$envir/cdas.$day/cdas1.t${cyc}z.syndata.tcvitals.tm00'
   fhbeg=12
   fhend=12
   ;;
  tcvges) geslist='
   $GETGES_COM/cfs/$envir/cdas.$day/cdas1.t${cyc}z.syndata.tcvitals.tm00'
   fhbeg=06
   fhend=06
   ;;
  tcvitl) geslist='
   $GETGES_COM/cfs/$envir/cdas.$day/cdas1.t${cyc}z.syndata.tcvitals.tm00'
   fhbeg=00
   fhend=00
   ;;
  icegrb) geslist='
   $GETGES_COM/cfs/$envir/cdas.$day/cdas1.t${cyc}z.engicegrb'
   fhbeg=00
   fhinc=06
   ;;
  icegri) geslist='
   $GETGES_COM/cfs/$envir/cdas.$day/cdas1.t${cyc}z.engicegrb.index'
   fhbeg=00
   fhinc=06
   ;;
  snogrb) geslist='
   $GETGES_COM/cfs/$envir/cdas.$day/cdas1.t${cyc}z.snogrb'
   fhbeg=00
   fhinc=06
   ;;
  snogrb_high) geslist='
   $GETGES_COM/cfs/$envir/cdas.$day/cdas1.t${cyc}z.snogrb_t574
   $GETGES_COM/cfs/$envir/cdas.$day/cdas1.t${cyc}z.snogrb_t382'
   fhbeg=00
   fhinc=06
   ;;
  snogrb_382) geslist='
   $GETGES_COM/cfs/$envir/cdas.$day/cdas1.t${cyc}z.snogrb_t382'
   fhbeg=00
   fhinc=06
   ;;
  snogrb_574) geslist='
   $GETGES_COM/cfs/$envir/cdas.$day/cdas1.t${cyc}z.snogrb_t574'
   fhbeg=00
   fhinc=06
   ;;
  snogri) geslist='
   $GETGES_COM/cfs/$envir/cdas.$day/cdas1.t${cyc}z.snogrb.index'
   fhbeg=00
   fhinc=06
   ;;
  sstgrb) geslist='
   $GETGES_COM/cfs/$envir/cdas.$day/cdas1.t${cyc}z.sstgrb'
   fhbeg=00
   fhinc=06
   ;;
  sstgri) geslist='
   $GETGES_COM/cfs/$envir/cdas.$day/cdas1.t${cyc}z.sstgrb.index'
   fhbeg=00
   fhinc=06
   ;;
 esac

# GFS
elif [[ $netwk = gfs ]];then
 fhend=384
 case $typef in
  sigges) geslist='
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.sf$fh'
   ;;
  siggm3) geslist='
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.sf$fhm3'
   ;;
  siggm2) geslist='
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.sf$fhm2'
   ;;
  siggm1) geslist='
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.sf$fhm1'
   ;;
  siggp1) geslist='
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.sf$fhp1'
   ;;
  siggp2) geslist='
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.sf$fhp2'
   ;;
  siggp3) geslist='
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.sf$fhp3'
   ;;
  sfcges) geslist='
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.bf$fh'
   ;;
  sfcgm3) geslist='
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.bf$fhm3'
   ;;
  sfcgm2) geslist='
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.bf$fhm2'
   ;;
  sfcgm1) geslist='
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.bf$fhm1'
   ;;
  sfcgp1) geslist='
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.bf$fhp1'
   ;;
  sfcgp2) geslist='
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.bf$fhp2'
   ;;
  sfcgp3) geslist='
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.bf$fhp3'
   ;;
  biascr) geslist='
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.abias'
   ;;
  satang) geslist='
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.satang'
   ;;
  satcnt) geslist='
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.satcnt'
   ;;
  gesfil) geslist='
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.gesfile'
   fhbeg=00
   fhend=00
   ;;
  sfgges) geslist='
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.sfluxgrbf$fh'
   ;;
  sfggp3)  geslist='
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.sfluxgrbf$fhp3'
   ;;
  pgbges) geslist='
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.pgrbf$fh'
   ;;
  pg2ges) geslist='
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.pgrb2.0p50.f0$fh$resolsuf'
   ;;
  pgiges) geslist='
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.pgrbif$fh'
   ;;
  pgbgm6) geslist='
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.pgrbf$fhm6'
   ;;
  pgigm6) geslist='
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.pgrbif$fhm6'
   ;;
  pgbgm3) geslist='
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.pgrbf$fhm3'
   ;;
  pgigm3) geslist='
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.pgrbif$fhm3'
   ;;
  pgbgp3) geslist='
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.pgrbf$fhp3'
   ;;
  pgigp3) geslist='
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.pgrbif$fhp3'
   ;;
  sigcur) geslist='
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.sf$fh'
   getlist00='
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.sanl'
   fhbeg=00
   ;;
  sfccur) geslist='
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.bf$fh'
   getlist00='
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.sfcanl'
   fhbeg=00
   ;;
  pgbcur) geslist='
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.pgrbf$fh'
   fhbeg=00
   ;;
  pg2cur) geslist='
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.pgrb2.0p50.f0$fh$resolsuf'
   fhbeg=00
   ;;
  pgicur) geslist='
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.pgrbif$fh'
   fhbeg=00
   ;;
  prepqc) geslist='
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.prepbufr'
   fhbeg=00
   fhend=00
   ;;
  tcvg12) geslist='
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.syndata.tcvitals.tm00'
   fhbeg=12
   fhend=12
   ;;
  tcvges) geslist='
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.syndata.tcvitals.tm00'
   fhbeg=06
   fhend=06
   ;;
  tcvitl) geslist='
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.syndata.tcvitals.tm00'
   fhbeg=00
   fhend=00
   ;;
  icegrb) geslist='
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.engicegrb'
   fhbeg=00
   fhinc=06
   ;;
  icegri) geslist='
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.engicegrb.index'
   fhbeg=00
   fhinc=06
   ;;
  snogrb) geslist='
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.snogrb'
   fhbeg=00
   fhinc=06
   ;;
  snogrb_high) geslist='
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.snogrb_t574
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.snogrb_t382'
   fhbeg=00
   fhinc=06
   ;;
  snogrb_382) geslist='
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.snogrb_t382'
   fhbeg=00
   fhinc=06
   ;;
  snogrb_574) geslist='
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.snogrb_t574'
   fhbeg=00
   fhinc=06
   ;;
  snogri) geslist='
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.snogrb.index'
   fhbeg=00
   fhinc=06
   ;;
  sstgrb) geslist='
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.sstgrb'
   fhbeg=00
   fhinc=06
   ;;
  sstgri) geslist='
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.sstgrb.index'
   fhbeg=00
   fhinc=06
   ;;
 esac

# GFS
elif [[ $netwk = gfs ]];then
 fhend=126
 case $typef in
  sigges) geslist='
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.sf$fh'
   ;;
  siggm3) geslist='
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.sf$fhm3'
   ;;
  siggm2) geslist='
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.sf$fhm2'
   ;;
  siggm1) geslist='
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.sf$fhm1'
   ;;
  siggp1) geslist='
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.sf$fhp1'
   ;;
  siggp2) geslist='
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.sf$fhp2'
   ;;
  siggp3) geslist='
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.sf$fhp3'
   ;;
  sfcges) geslist='
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.bf$fh'
   ;;
  sfcgm3) geslist='
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.bf$fhm3'
   ;;
  sfcgm2) geslist='
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.bf$fhm2'
   ;;
  sfcgm1) geslist='
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.bf$fhm1'
   ;;
  sfcgp1) geslist='
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.bf$fhp1'
   ;;
  sfcgp2) geslist='
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.bf$fhp2'
   ;;
  sfcgp3) geslist='
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.bf$fhp3'
   ;;
  biascr) geslist='
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.abias'
   ;;
  satang) geslist='
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.satang'
   ;;
  satcnt) geslist='
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.satcnt'
   ;;
  gesfil) geslist='
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.gesfile'
   fhbeg=00
   fhend=00
   ;;
  sfgges) geslist='
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.sfluxgrbf$fh'
   ;;
  sfggp3)  geslist='
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.sfluxgrbf$fhp3'
   ;;
  pgbges) geslist='
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.pgrbf$fh'
   ;;
  pgiges) geslist='
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.pgrbif$fh'
   ;;
  pgbgm6) geslist='
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.pgrbf$fhm6'
   ;;
  pgigm6) geslist='
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.pgrbif$fhm6'
   ;;
  pgbgm3) geslist='
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.pgrbf$fhm3'
   ;;
  pgigm3) geslist='
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.pgrbif$fhm3'
   ;;
  pgbgp3) geslist='
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.pgrbf$fhp3'
   ;;
  pgigp3) geslist='
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.pgrbif$fhp3'
   ;;
  sigcur) geslist='
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.sf$fh'
   getlist00='
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.sanl'
   fhbeg=00
   ;;
  sfccur) geslist='
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.bf$fh'
   getlist00='
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.sfcanl'
   fhbeg=00
   ;;
  pgbcur) geslist='
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.pgrbf$fh'
   fhbeg=00
   ;;
  pgicur) geslist='
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.pgrbif$fh'
   fhbeg=00
   ;;
  prepqc) geslist='
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.prepbufr'
   fhbeg=00
   fhend=00
   ;;
  tcvg12) geslist='
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.syndata.tcvitals.tm00'
   fhbeg=12
   fhend=12
   ;;
  tcvges) geslist='
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.syndata.tcvitals.tm00'
   fhbeg=06
   fhend=06
   ;;
  tcvitl) geslist='
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.syndata.tcvitals.tm00'
   fhbeg=00
   fhend=00
   ;;
  icegrb) geslist='
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.engicegrb'
   fhbeg=00
   fhinc=06
   ;;
  icegri) geslist='
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.engicegrb.index'
   fhbeg=00
   fhinc=06
   ;;
  snogrb) geslist='
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.snogrb'
   fhbeg=00
   fhinc=06
   ;;
  snogrb_high) geslist='
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.snogrb_t574 
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.snogrb_t382'
   fhbeg=00
   fhinc=06
   ;;
  snogrb_382) geslist='
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.snogrb_t382' 
   fhbeg=00
   fhinc=06
   ;;
  snogrb_574) geslist='
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.snogrb_t574'
   fhbeg=00
   fhinc=06
   ;;
  snogri) geslist='
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.snogrb.index'
   fhbeg=00
   fhinc=06
   ;;
  sstgrb) geslist='
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.sstgrb'
   fhbeg=00
   fhinc=06
   ;;
  sstgri) geslist='
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.sstgrb.index'
   fhbeg=00
   fhinc=06
   ;;
 esac
 echo '************************************************************' >&2
 echo '* CAUTION: Using "-n gfs" is now deprecated.               *' >&2
 echo '*          Please use "-n gfs".                            *' >&2       
 echo '************************************************************' >&2

# CDAS
elif [[ $netwk = cdas ]];then
 fhbeg=06
 fhend=06
 case $typef in
  sigges)  geslist='
   $GETGES_COM/cdas/$envir/cdas.$day/cdas.t${cyc}z.sf$fh'
   ;;
  siggm3) geslist='
   $GETGES_COM/cdas/$envir/cdas.$day/cdas.t${cyc}z.sf$fhm3'
   ;;
  siggm2) geslist='
   $GETGES_COM/cdas/$envir/cdas.$day/cdas.t${cyc}z.sf$fhm2'
   ;;
  siggm1) geslist='
   $GETGES_COM/cdas/$envir/cdas.$day/cdas.t${cyc}z.sf$fhm1'
   ;;
  siggp1) geslist='
   $GETGES_COM/cdas/$envir/cdas.$day/cdas.t${cyc}z.sf$fhp1'
   ;;
  siggp2) geslist='
   $GETGES_COM/cdas/$envir/cdas.$day/cdas.t${cyc}z.sf$fhp2'
   ;;
  siggp3) geslist='
   $GETGES_COM/cdas/$envir/cdas.$day/cdas.t${cyc}z.sf$fhp3'
   ;;
  sfcges) geslist='
   $GETGES_COM/cdas/$envir/cdas.$day/cdas.t${cyc}z.bf$fh'
   ;;
  sfcgm3) geslist='
   $GETGES_COM/cdas/$envir/cdas.$day/cdas.t${cyc}z.bf$fhm3'
   ;;
  sfcgm2) geslist='
   $GETGES_COM/cdas/$envir/cdas.$day/cdas.t${cyc}z.bf$fhm2'
   ;;
  sfcgm1) geslist='
   $GETGES_COM/cdas/$envir/cdas.$day/cdas.t${cyc}z.bf$fhm1'
   ;;
  sfcgp1) geslist='
   $GETGES_COM/cdas/$envir/cdas.$day/cdas.t${cyc}z.bf$fhp1'
   ;;
  sfcgp2) geslist='
   $GETGES_COM/cdas/$envir/cdas.$day/cdas.t${cyc}z.bf$fhp2'
   ;;
  sfcgp3) geslist='
   $GETGES_COM/cdas/$envir/cdas.$day/cdas.t${cyc}z.bf$fhp3'
   ;;
  biascr) geslist='
   $GETGES_COM/cdas/$envir/cdas.$day/cdas.t${cyc}z.abias'
   ;;
  satang) geslist='
   $GETGES_COM/cdas/$envir/cdas.$day/cdas.t${cyc}z.satang'
   ;;
  satcnt) geslist='
   $GETGES_COM/cdas/$envir/cdas.$day/cdas.t${cyc}z.satcnt'
   ;;
  gesfil) geslist='
   $GETGES_COM/cdas/$envir/cdas.$day/cdas.t${cyc}z.gesfile'
   fhbeg=00
   fhend=00
   ;;
  pgbges) geslist='
   $GETGES_COM/cdas/$envir/cdas.$day/cdas.t${cyc}z.pgrbf$fh'
   ;;
  pgiges) geslist='
   $GETGES_COM/cdas/$envir/cdas.$day/cdas.t${cyc}z.pgrbif$fh'
   ;;
  pgbgm6) geslist='
   $GETGES_COM/cdas/$envir/cdas.$day/cdas.t${cyc}z.pgrbf$fhm6'
   ;;
  pgigm6) geslist='
   $GETGES_COM/cdas/$envir/cdas.$day/cdas.t${cyc}z.pgrbif$fhm6'
   ;;
  pgbgm3) geslist='
   $GETGES_COM/cdas/$envir/cdas.$day/cdas.t${cyc}z.pgrbf$fhm3'
   ;;
  pgigm3) geslist='
   $GETGES_COM/cdas/$envir/cdas.$day/cdas.t${cyc}z.pgrbif$fhm3'
   ;;
  pgbgp3) geslist='
   $GETGES_COM/cdas/$envir/cdas.$day/cdas.t${cyc}z.pgrbf$fhp3'
   ;;
  pgigp3) geslist='
   $GETGES_COM/cdas/$envir/cdas.$day/cdas.t${cyc}z.pgrbif$fhp3'
   ;;
  sigcur) geslist='
   $GETGES_COM/cdas/$envir/cdas.$day/cdas.t${cyc}z.sf$fh'
   getlist00='
   $GETGES_COM/cdas/$envir/cdas.$day/cdas.t${cyc}z.sanl'
   fhbeg=00
   ;;
  sfccur) geslist='
   $GETGES_COM/cdas/$envir/cdas.$day/cdas.t${cyc}z.bf$fh'
   getlist00='
   $GETGES_COM/cdas/$envir/cdas.$day/cdas.t${cyc}z.sfcanl'
   fhbeg=00
   ;;
  pgbcur) geslist='
   $GETGES_COM/cdas/$envir/cdas.$day/cdas.t${cyc}z.pgrbf$fh'
   fhbeg=00
   ;;
  pgicur) geslist='
   $GETGES_COM/cdas/$envir/cdas.$day/cdas.t${cyc}z.pgrbif$fh'
   fhbeg=00
   ;;
  prepqc) geslist='
   $GETGES_COM/cdas/$envir/cdas.$day/cdas.t${cyc}z.prepbufr'
   fhbeg=00
   fhend=00
   ;;
  tcvg12) geslist='
   $GETGES_COM/cdas/$envir/cdas.$day/cdas.t${cyc}z.syndata.tcvitals.tm00'
   fhbeg=12
   fhend=12
   ;;
  tcvges) geslist='
   $GETGES_COM/cdas/$envir/cdas.$day/cdas.t${cyc}z.syndata.tcvitals.tm00'
   fhbeg=06
   fhend=06
   ;;
  tcvitl) geslist='
   $GETGES_COM/cdas/$envir/cdas.$day/cdas.t${cyc}z.syndata.tcvitals.tm00'
   fhbeg=00
   fhend=00
   ;;
  icegrb) geslist='
   $GETGES_COM/cdas/$envir/cdas.$day/cdas.t${cyc}z.engicegrb'
   fhbeg=00
   fhinc=06
   ;;
  icegri) geslist='
   $GETGES_COM/cdas/$envir/cdas.$day/cdas.t${cyc}z.engicegrb.index'
   fhbeg=00
   fhinc=06
   ;;
  snogrb) geslist='
   $GETGES_COM/cdas/$envir/cdas.$day/cdas.t${cyc}z.snogrb'
   fhbeg=00
   fhinc=06
   ;;
  snogri) geslist='
   $GETGES_COM/cdas/$envir/cdas.$day/cdas.t${cyc}z.snogrb.index'
   fhbeg=00
   fhinc=06
   ;;
  sstgrb) geslist='
   $GETGES_COM/cdas/$envir/cdas.$day/cdas.t${cyc}z.sstgrb'
   fhbeg=00
   fhinc=06
   ;;
  sstgri) geslist='
   $GETGES_COM/cdas/$envir/cdas.$day/cdas.t${cyc}z.sstgrb.index'
   fhbeg=00
   fhinc=06
   ;;
 esac

# CDC CDAS
elif [[ $netwk = cdc ]];then
 fhbeg=06
 fhend=06
 case $typef in
  sigges)  geslist='
   $GETGES_COM/cdc/$envir/cdas.$day/cdas.t${cyc}z.sf$fh'
   ;;
  siggm3) geslist='
   $GETGES_COM/cdc/$envir/cdas.$day/cdas.t${cyc}z.sf$fhm3'
   ;;
  siggm2) geslist='
   $GETGES_COM/cdc/$envir/cdas.$day/cdas.t${cyc}z.sf$fhm2'
   ;;
  siggm1) geslist='
   $GETGES_COM/cdc/$envir/cdas.$day/cdas.t${cyc}z.sf$fhm1'
   ;;
  siggp1) geslist='
   $GETGES_COM/cdc/$envir/cdas.$day/cdas.t${cyc}z.sf$fhp1'
   ;;
  siggp2) geslist='
   $GETGES_COM/cdc/$envir/cdas.$day/cdas.t${cyc}z.sf$fhp2'
   ;;
  siggp3) geslist='
   $GETGES_COM/cdc/$envir/cdas.$day/cdas.t${cyc}z.sf$fhp3'
   ;;
  sfcges) geslist='
   $GETGES_COM/cdc/$envir/cdas.$day/cdas.t${cyc}z.bf$fh'
   ;;
  sfcgm3) geslist='
   $GETGES_COM/cdc/$envir/cdas.$day/cdas.t${cyc}z.bf$fhm3'
   ;;
  sfcgm2) geslist='
   $GETGES_COM/cdc/$envir/cdas.$day/cdas.t${cyc}z.bf$fhm2'
   ;;
  sfcgm1) geslist='
   $GETGES_COM/cdc/$envir/cdas.$day/cdas.t${cyc}z.bf$fhm1'
   ;;
  sfcgp1) geslist='
   $GETGES_COM/cdc/$envir/cdas.$day/cdas.t${cyc}z.bf$fhp1'
   ;;
  sfcgp2) geslist='
   $GETGES_COM/cdc/$envir/cdas.$day/cdas.t${cyc}z.bf$fhp2'
   ;;
  sfcgp3) geslist='
   $GETGES_COM/cdc/$envir/cdas.$day/cdas.t${cyc}z.bf$fhp3'
   ;;
  biascr) geslist='
   $GETGES_COM/cdc/$envir/cdas.$day/cdas.t${cyc}z.abias'
   ;;
  satang) geslist='
   $GETGES_COM/cdc/$envir/cdas.$day/cdas.t${cyc}z.satang'
   ;;
  satcnt) geslist='
   $GETGES_COM/cdc/$envir/cdas.$day/cdas.t${cyc}z.satcnt'
   ;;
  gesfil) geslist='
   $GETGES_COM/cdc/$envir/cdas.$day/cdas.t${cyc}z.gesfile'
   fhbeg=00
   fhend=00
   ;;
  pgbges) geslist='
   $GETGES_COM/cdc/$envir/cdas.$day/cdas.t${cyc}z.pgrbf$fh'
   ;;
  pgiges) geslist='
   $GETGES_COM/cdc/$envir/cdas.$day/cdas.t${cyc}z.pgrbif$fh'
   ;;
  pgbgm6) geslist='
   $GETGES_COM/cdc/$envir/cdas.$day/cdas.t${cyc}z.pgrbf$fhm6'
   ;;
  pgigm6) geslist='
   $GETGES_COM/cdc/$envir/cdas.$day/cdas.t${cyc}z.pgrbif$fhm6'
   ;;
  pgbgm3) geslist='
   $GETGES_COM/cdc/$envir/cdas.$day/cdas.t${cyc}z.pgrbf$fhm3'
   ;;
  pgigm3) geslist='
   $GETGES_COM/cdc/$envir/cdas.$day/cdas.t${cyc}z.pgrbif$fhm3'
   ;;
  pgbgp3) geslist='
   $GETGES_COM/cdc/$envir/cdas.$day/cdas.t${cyc}z.pgrbf$fhp3'
   ;;
  pgigp3) geslist='
   $GETGES_COM/cdc/$envir/cdas.$day/cdas.t${cyc}z.pgrbif$fhp3'
   ;;
  sigcur) geslist='
   $GETGES_COM/cdc/$envir/cdas.$day/cdas.t${cyc}z.sf$fh'
   getlist00='
   $GETGES_COM/cdc/$envir/cdas.$day/cdas.t${cyc}z.sanl'
   fhbeg=00
   ;;
  sfccur) geslist='
   $GETGES_COM/cdc/$envir/cdas.$day/cdas.t${cyc}z.bf$fh'
   getlist00='
   $GETGES_COM/cdc/$envir/cdas.$day/cdas.t${cyc}z.sfcanl'
   fhbeg=00
   ;;
  pgbcur) geslist='
   $GETGES_COM/cdc/$envir/cdas.$day/cdas.t${cyc}z.pgrbf$fh'
   fhbeg=00
   ;;
  pgicur) geslist='
   $GETGES_COM/cdc/$envir/cdas.$day/cdas.t${cyc}z.pgrbif$fh'
   fhbeg=00
   ;;
  prepqc) geslist='
   $GETGES_COM/cdc/$envir/cdas.$day/cdas.t${cyc}z.prepbufr'
   fhbeg=00
   fhend=00
   ;;
  tcvg12) geslist='
   $GETGES_COM/cdc/$envir/cdas.$day/cdas.t${cyc}z.syndata.tcvitals.tm00'
   fhbeg=12
   fhend=12
   ;;
  tcvges) geslist='
   $GETGES_COM/cdc/$envir/cdas.$day/cdas.t${cyc}z.syndata.tcvitals.tm00'
   fhbeg=06
   fhend=06
   ;;
  tcvitl) geslist='
   $GETGES_COM/cdc/$envir/cdas.$day/cdas.t${cyc}z.syndata.tcvitals.tm00'
   fhbeg=00
   fhend=00
   ;;
  icegrb) geslist='
   $GETGES_COM/cdc/$envir/cdas.$day/cdas.t${cyc}z.engicegrb'
   fhbeg=00
   fhinc=06
   ;;
  icegri) geslist='
   $GETGES_COM/cdc/$envir/cdas.$day/cdas.t${cyc}z.engicegrb.index'
   fhbeg=00
   fhinc=06
   ;;
  snogrb) geslist='
   $GETGES_COM/cdc/$envir/cdas.$day/cdas.t${cyc}z.snogrb'
   fhbeg=00
   fhinc=06
   ;;
  snogri) geslist='
   $GETGES_COM/cdc/$envir/cdas.$day/cdas.t${cyc}z.snogrb.index'
   fhbeg=00
   fhinc=06
   ;;
  sstgrb) geslist='
   $GETGES_COM/cdc/$envir/cdas.$day/cdas.t${cyc}z.sstgrb'
   fhbeg=00
   fhinc=06
   ;;
  sstgri) geslist='
   $GETGES_COM/cdc/$envir/cdas.$day/cdas.t${cyc}z.sstgrb.index'
   fhbeg=00
   fhinc=06
   ;;
 esac

# MRF
elif [[ $netwk = mrf ]];then
 fhend=384
 case $typef in
  sigges) geslist='
   $GETGES_COM/mrf/$envir/mrf.$day/drfmr.t${cyc}z.sf$fh'
   ;;
  siggm3) geslist='
   $GETGES_COM/mrf/$envir/mrf.$day/drfmr.t${cyc}z.sf$fhm3'
   ;;
  siggm2) geslist='
   $GETGES_COM/mrf/$envir/mrf.$day/drfmr.t${cyc}z.sf$fhm2'
   ;;
  siggm1) geslist='
   $GETGES_COM/mrf/$envir/mrf.$day/drfmr.t${cyc}z.sf$fhm1'
   ;;
  siggp1) geslist='
   $GETGES_COM/mrf/$envir/mrf.$day/drfmr.t${cyc}z.sf$fhp1'
   ;;
  siggp2) geslist='
   $GETGES_COM/mrf/$envir/mrf.$day/drfmr.t${cyc}z.sf$fhp2'
   ;;
  siggp3) geslist='
   $GETGES_COM/mrf/$envir/mrf.$day/drfmr.t${cyc}z.sf$fhp3'
   ;;
  sfcges) geslist='
   $GETGES_COM/mrf/$envir/mrf.$day/drfmr.t${cyc}z.bf$fh'
   ;;
  sfcgm3) geslist='
   $GETGES_COM/mrf/$envir/mrf.$day/drfmr.t${cyc}z.bf$fhm3'
   ;;
  sfcgm2) geslist='
   $GETGES_COM/mrf/$envir/mrf.$day/drfmr.t${cyc}z.bf$fhm2'
   ;;
  sfcgm1) geslist='
   $GETGES_COM/mrf/$envir/mrf.$day/drfmr.t${cyc}z.bf$fhm1'
   ;;
  sfcgp1) geslist='
   $GETGES_COM/mrf/$envir/mrf.$day/drfmr.t${cyc}z.bf$fhp1'
   ;;
  sfcgp2) geslist='
   $GETGES_COM/mrf/$envir/mrf.$day/drfmr.t${cyc}z.bf$fhp2'
   ;;
  sfcgp3) geslist='
   $GETGES_COM/mrf/$envir/mrf.$day/drfmr.t${cyc}z.bf$fhp3'
   ;;
  biascr) geslist='
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.abias'
   ;;
  satang) geslist='
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.satang'
   ;;
  satcnt) geslist='
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.satcnt'
   ;;
  gesfil) geslist='
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.gesfile'
   fhbeg=00
   fhend=00
   ;;
  pgbges) geslist='
   $GETGES_COM/mrf/$envir/mrf.$day/drfmr.t${cyc}z.pgrbf$fh'
   ;;
  pgiges) geslist='
   $GETGES_COM/mrf/$envir/mrf.$day/drfmr.t${cyc}z.pgrbif$fh'
   ;;
  pgbgm6) geslist='
   $GETGES_COM/mrf/$envir/mrf.$day/drfmr.t${cyc}z.pgrbf$fhm6'
   ;;
  pgigm6) geslist='
   $GETGES_COM/mrf/$envir/mrf.$day/drfmr.t${cyc}z.pgrbif$fhm6'
   ;;
  pgbgm3) geslist='
   $GETGES_COM/mrf/$envir/mrf.$day/drfmr.t${cyc}z.pgrbf$fhm3'
   ;;
  pgigm3) geslist='
   $GETGES_COM/mrf/$envir/mrf.$day/drfmr.t${cyc}z.pgrbif$fhm3'
   ;;
  pgbgp3) geslist='
   $GETGES_COM/mrf/$envir/mrf.$day/drfmr.t${cyc}z.pgrbf$fhp3'
   ;;
  pgigp3) geslist='
   $GETGES_COM/mrf/$envir/mrf.$day/drfmr.t${cyc}z.pgrbif$fhp3'
   ;;
  sigcur) geslist='
   $GETGES_COM/mrf/$envir/mrf.$day/drfmr.t${cyc}z.sf$fh'
   getlist00='
   $GETGES_COM/mrf/$envir/mrf.$day/drfmr.t${cyc}z.sanl'
   fhbeg=00
   ;;
  sfccur) geslist='
   $GETGES_COM/mrf/$envir/mrf.$day/drfmr.t${cyc}z.bf$fh'
   getlist00='
   $GETGES_COM/mrf/$envir/mrf.$day/drfmr.t${cyc}z.sfcanl'
   fhbeg=00
   ;;
  pgbcur) geslist='
   $GETGES_COM/mrf/$envir/mrf.$day/drfmr.t${cyc}z.pgrbf$fh'
   fhbeg=00
   ;;
  pgicur) geslist='
   $GETGES_COM/mrf/$envir/mrf.$day/drfmr.t${cyc}z.pgrbif$fh'
   fhbeg=00
   ;;
  prepqc) geslist='
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.prepbufr'
   fhbeg=00
   fhend=00
   ;;
  tcvg12) geslist='
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.syndata.tcvitals.tm00'
   fhbeg=12
   fhend=12
   ;;
  tcvges) geslist='
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.syndata.tcvitals.tm00'
   fhbeg=06
   fhend=06
   ;;
  tcvitl) geslist='
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.syndata.tcvitals.tm00'
   fhbeg=00
   fhend=00
   ;;
  icegrb) geslist='
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.engicegrb'
   fhbeg=00
   fhinc=06
   ;;
  icegri) geslist='
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.engicegrb.index'
   fhbeg=00
   fhinc=06
   ;;
  snogrb) geslist='
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.snogrb'
   fhbeg=00
   fhinc=06
   ;;
  snogrb_high) geslist='
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.snogrb_t574 
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.snogrb_t382'
   fhbeg=00
   fhinc=06
   ;;
  snogrb_382) geslist='
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.snogrb_t382' 
   fhbeg=00
   fhinc=06
   ;;
  snogrb_574) geslist='
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.snogrb_t574' 
   fhbeg=00
   fhinc=06
   ;;
  snogri) geslist='
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.snogrb.index'
   fhbeg=00
   fhinc=06
   ;;
  sstgrb) geslist='
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.sstgrb'
   fhbeg=00
   fhinc=06
   ;;
  sstgri) geslist='
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.sstgrb.index'
   fhbeg=00
   fhinc=06
   ;;
 esac
 echo '************************************************************' >&2
 echo '* CAUTION: Using "-n mrf" is now deprecated.               *' >&2
 echo '*          Please use "-n gfs".                            *' >&2       
 echo '************************************************************' >&2

# PRZ
elif [[ $netwk = prz ]];then
 fhend=384
 case $typef in
  sigges) geslist='
   $GETGES_COM/gfs/$envir/gdas.$day/gdas2.t${cyc}z.sf$fh
   $GETGES_COM/mrf/$envir/mrf.$day/drf01.t${cyc}z.sf$fh'
   ;;
  siggm3) geslist='
   $GETGES_COM/gfs/$envir/gdas.$day/gdas2.t${cyc}z.sf$fhm3
   $GETGES_COM/mrf/$envir/mrf.$day/drf01.t${cyc}z.sf$fhm3'
   ;;
  siggm2) geslist='
   $GETGES_COM/gfs/$envir/gdas.$day/gdas2.t${cyc}z.sf$fhm2
   $GETGES_COM/mrf/$envir/mrf.$day/drf01.t${cyc}z.sf$fhm2'
   ;;
  siggm1) geslist='
   $GETGES_COM/gfs/$envir/gdas.$day/gdas2.t${cyc}z.sf$fhm1
   $GETGES_COM/mrf/$envir/mrf.$day/drf01.t${cyc}z.sf$fhm1'
   ;;
  siggp1) geslist='
   $GETGES_COM/gfs/$envir/gdas.$day/gdas2.t${cyc}z.sf$fhp1
   $GETGES_COM/mrf/$envir/mrf.$day/drf01.t${cyc}z.sf$fhp1'
   ;;
  siggp2) geslist='
   $GETGES_COM/gfs/$envir/gdas.$day/gdas2.t${cyc}z.sf$fhp2
   $GETGES_COM/mrf/$envir/mrf.$day/drf01.t${cyc}z.sf$fhp2'
   ;;
  siggp3) geslist='
   $GETGES_COM/gfs/$envir/gdas.$day/gdas2.t${cyc}z.sf$fhp3
   $GETGES_COM/mrf/$envir/mrf.$day/drf01.t${cyc}z.sf$fhp3'
   ;;
  sfcges) geslist='
   $GETGES_COM/gfs/$envir/gdas.$day/gdas2.t${cyc}z.bf$fh
   $GETGES_COM/mrf/$envir/mrf.$day/drf01.t${cyc}z.bf$fh'
   ;;
  sfcgm3) geslist='
   $GETGES_COM/gfs/$envir/gdas.$day/gdas2.t${cyc}z.bf$fhm3
   $GETGES_COM/mrf/$envir/mrf.$day/drf01.t${cyc}z.bf$fhm3'
   ;;
  sfcgm2) geslist='
   $GETGES_COM/gfs/$envir/gdas.$day/gdas2.t${cyc}z.bf$fhm2
   $GETGES_COM/mrf/$envir/mrf.$day/drf01.t${cyc}z.bf$fhm2'
   ;;
  sfcgm1) geslist='
   $GETGES_COM/gfs/$envir/gdas.$day/gdas2.t${cyc}z.bf$fhm1
   $GETGES_COM/mrf/$envir/mrf.$day/drf01.t${cyc}z.bf$fhm1'
   ;;
  sfcgp1) geslist='
   $GETGES_COM/gfs/$envir/gdas.$day/gdas2.t${cyc}z.bf$fhp1
   $GETGES_COM/mrf/$envir/mrf.$day/drf01.t${cyc}z.bf$fhp1'
   ;;
  sfcgp2) geslist='
   $GETGES_COM/gfs/$envir/gdas.$day/gdas2.t${cyc}z.bf$fhp2
   $GETGES_COM/mrf/$envir/mrf.$day/drf01.t${cyc}z.bf$fhp2'
   ;;
  sfcgp3) geslist='
   $GETGES_COM/gfs/$envir/gdas.$day/gdas2.t${cyc}z.bf$fhp3
   $GETGES_COM/mrf/$envir/mrf.$day/drf01.t${cyc}z.bf$fhp3'
   ;;
  biascr) geslist='
   $GETGES_COM/gfs/$envir/gdas.$day/gdas2.t${cyc}z.abias'
   ;;
  satang) geslist='
   $GETGES_COM/gfs/$envir/gdas.$day/gdas2.t${cyc}z.satang'
   ;;
  satcnt) geslist='
   $GETGES_COM/gfs/$envir/gdas.$day/gdas2.t${cyc}z.satcnt'
   ;;
  gesfil) geslist='
   $GETGES_COM/gfs/$envir/gdas.$day/gdas2.t${cyc}z.gesfile'
   fhbeg=00
   fhend=00
   ;;
  pgbges) geslist='
   $GETGES_COM/gfs/$envir/gdas.$day/gdas2.t${cyc}z.pgrbf$fh
   $GETGES_COM/mrf/$envir/mrf.$day/drf01.t${cyc}z.pgrbf$fh'
   ;;
  pgiges) geslist='
   $GETGES_COM/gfs/$envir/gdas.$day/gdas2.t${cyc}z.pgrbif$fh
   $GETGES_COM/mrf/$envir/mrf.$day/drf01.t${cyc}z.pgrbif$fh'
   ;;
  pgbgm6) geslist='
   $GETGES_COM/gfs/$envir/gdas.$day/gdas2.t${cyc}z.pgrbf$fhm6
   $GETGES_COM/mrf/$envir/mrf.$day/drf01.t${cyc}z.pgrbf$fhm6'
   ;;
  pgigm6) geslist='
   $GETGES_COM/gfs/$envir/gdas.$day/gdas2.t${cyc}z.pgrbif$fhm6
   $GETGES_COM/mrf/$envir/mrf.$day/drf01.t${cyc}z.pgrbif$fhm6'
   ;;
  pgbgm3) geslist='
   $GETGES_COM/gfs/$envir/gdas.$day/gdas2.t${cyc}z.pgrbf$fhm3
   $GETGES_COM/mrf/$envir/mrf.$day/drf01.t${cyc}z.pgrbf$fhm3'
   ;;
  pgigm3) geslist='
   $GETGES_COM/gfs/$envir/gdas.$day/gdas2.t${cyc}z.pgrbif$fhm3
   $GETGES_COM/mrf/$envir/mrf.$day/drf01.t${cyc}z.pgrbif$fhm3'
   ;;
  pgbgp3) geslist='
   $GETGES_COM/gfs/$envir/gdas.$day/gdas2.t${cyc}z.pgrbf$fhp3
   $GETGES_COM/mrf/$envir/mrf.$day/drf01.t${cyc}z.pgrbf$fhp3'
   ;;
  pgigp3) geslist='
   $GETGES_COM/gfs/$envir/gdas.$day/gdas2.t${cyc}z.pgrbif$fhp3
   $GETGES_COM/mrf/$envir/mrf.$day/drf01.t${cyc}z.pgrbif$fhp3'
   ;;
  sigcur) geslist='
   $GETGES_COM/gfs/$envir/gdas.$day/gdas2.t${cyc}z.sf$fh
   $GETGES_COM/mrf/$envir/mrf.$day/drf01.t${cyc}z.sf$fh'
   getlist00='
   $GETGES_COM/gfs/$envir/gdas.$day/gdas2.t${cyc}z.sanl'
   fhbeg=00
   ;;
  sfccur) geslist='
   $GETGES_COM/gfs/$envir/gdas.$day/gdas2.t${cyc}z.bf$fh
   $GETGES_COM/mrf/$envir/mrf.$day/drf01.t${cyc}z.bf$fh'
   getlist00='
   $GETGES_COM/gfs/$envir/gdas.$day/gdas2.t${cyc}z.sfcanl'
   fhbeg=00
   ;;
  pgbcur) geslist='
   $GETGES_COM/gfs/$envir/gdas.$day/gdas2.t${cyc}z.pgrbf$fh
   $GETGES_COM/mrf/$envir/mrf.$day/drf01.t${cyc}z.pgrbf$fh'
   fhbeg=00
   ;;
  pgicur) geslist='
   $GETGES_COM/gfs/$envir/gdas.$day/gdas2.t${cyc}z.pgrbif$fh
   $GETGES_COM/mrf/$envir/mrf.$day/drf01.t${cyc}z.pgrbif$fh'
   fhbeg=00
   ;;
  prepqc) geslist='
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.prepbufr'
   fhbeg=00
   fhend=00
   ;;
  tcvg12) geslist='
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.syndata.tcvitals.tm00'
   fhbeg=12
   fhend=12
   ;;
  tcvges) geslist='
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.syndata.tcvitals.tm00'
   fhbeg=06
   fhend=06
   ;;
  tcvitl) geslist='
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.syndata.tcvitals.tm00'
   fhbeg=00
   fhend=00
   ;;
  icegrb) geslist='
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.engicegrb'
   fhbeg=00
   fhinc=06
   ;;
  icegri) geslist='
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.engicegrb.index'
   fhbeg=00
   fhinc=06
   ;;
  snogrb) geslist='
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.snogrb'
   fhbeg=00
   fhinc=06
   ;;
  snogrb_high) geslist='
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.snogrb_t574 
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.snogrb_t382'
   fhbeg=00
   fhinc=06
   ;;
  snogrb_382) geslist='
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.snogrb_t382' 
   fhbeg=00
   fhinc=06
   ;;
  snogrb_574) geslist='
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.snogrb_t574' 
   fhbeg=00
   fhinc=06
   ;;
  snogri) geslist='
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.snogrb.index'
   fhbeg=00
   fhinc=06
   ;;
  sstgrb) geslist='
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.sstgrb'
   fhbeg=00
   fhinc=06
   ;;
  sstgri) geslist='
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.sstgrb.index'
   fhbeg=00
   fhinc=06
   ;;
 esac
 echo '************************************************************' >&2
 echo '* CAUTION: Using "-n prz" is now deprecated.               *' >&2
 echo '*          Please use "-n gfs".                            *' >&2       
 echo '************************************************************' >&2

# High resolution production
elif [[ $netwk = global && $resol = high ]];then
 case $typef in
  sigges) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.sf$fh
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.sf$fh
   $GETGES_NWG/$envir/gfs.$day/gfs.t${cyc}z.sf$fh
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.sf$fh'
   ;;
  siggm3) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.sf$fhm3
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.sf$fhm3
   $GETGES_NWG/$envir/gfs.$day/gfs.t${cyc}z.sf$fhm3
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.sf$fhm3'
   ;;
  siggm2) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.sf$fhm2
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.sf$fhm2
   $GETGES_NWG/$envir/gfs.$day/gfs.t${cyc}z.sf$fhm2
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.sf$fhm2'
   ;;
  siggm1) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.sf$fhm1
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.sf$fhm1
   $GETGES_NWG/$envir/gfs.$day/gfs.t${cyc}z.sf$fhm1
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.sf$fhm1'
   ;;
  siggp1) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.sf$fhp1
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.sf$fhp1
   $GETGES_NWG/$envir/gfs.$day/gfs.t${cyc}z.sf$fhp1
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.sf$fhp1'
   ;;
  siggp2) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.sf$fhp2
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.sf$fhp2
   $GETGES_NWG/$envir/gfs.$day/gfs.t${cyc}z.sf$fhp2
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.sf$fhp2'
   ;;
  siggp3) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.sf$fhp3
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.sf$fhp3
   $GETGES_NWG/$envir/gfs.$day/gfs.t${cyc}z.sf$fhp3
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.sf$fhp3'
   ;;
  sfcges) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.bf$fh
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.bf$fh
   $GETGES_NWG/$envir/gfs.$day/gfs.t${cyc}z.bf$fh
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.bf$fh'
   ;;
  sfcgm3) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.bf$fhm3
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.bf$fhm3
   $GETGES_NWG/$envir/gfs.$day/gfs.t${cyc}z.bf$fhm3
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.bf$fhm3'
   ;;
  sfcgm2) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.bf$fhm2
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.bf$fhm2
   $GETGES_NWG/$envir/gfs.$day/gfs.t${cyc}z.bf$fhm2
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.bf$fhm2'
   ;;
  sfcgm1) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.bf$fhm1
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.bf$fhm1
   $GETGES_NWG/$envir/gfs.$day/gfs.t${cyc}z.bf$fhm1
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.bf$fhm1'
   ;;
  sfcgp1) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.bf$fhp1
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.bf$fhp1
   $GETGES_NWG/$envir/gfs.$day/gfs.t${cyc}z.bf$fhp1
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.bf$fhp1'
   ;;
  sfcgp2) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.bf$fhp2
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.bf$fhp2
   $GETGES_NWG/$envir/gfs.$day/gfs.t${cyc}z.bf$fhp2
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.bf$fhp2'
   ;;
  sfcgp3) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.bf$fhp3
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.bf$fhp3
   $GETGES_NWG/$envir/gfs.$day/gfs.t${cyc}z.bf$fhp3
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.bf$fhp3'
   ;;
  biascr) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.abias
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.abias
   $GETGES_NWG/$envir/gfs.$day/gfs.t${cyc}z.abias
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.abias'
   fhbeg=06
   fhinc=06
   ;;
  satang) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.satang
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.satang
   $GETGES_NWG/$envir/gfs.$day/gfs.t${cyc}z.satang
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.satang'
   fhbeg=06
   fhinc=06
   ;;
  satcnt) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.satcnt
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.satcnt
   $GETGES_NWG/$envir/gfs.$day/gfs.t${cyc}z.satcnt
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.satcnt'
   fhbeg=06
   fhinc=06
   ;;
  gesfil) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.gesfile
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.gesfile
   $GETGES_NWG/$envir/gfs.$day/gfs.t${cyc}z.gesfile
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.gesfile'
   fhbeg=00
   fhend=00
   ;;
  sfgges) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.sfluxgrbf$fh
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.sfluxgrbf$fh
   $GETGES_NWG/$envir/gfs.$day/gfs.t${cyc}z.sfluxgrbf$fh
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.sfluxgrbf$fh'
   ;;
  sfggp3) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.sfluxgrbf$fhp3
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.sfluxgrbf$fhp3
   $GETGES_NWG/$envir/gfs.$day/gfs.t${cyc}z.sfluxgrbf$fhp3
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.sfluxgrbf$fhp3'
   ;;
  pgbges) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.pgrbh$fh
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.pgrbf$fh
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.pgrbh$fh
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.pgrbf$fh
   $GETGES_NWG/$envir/gfs.$day/gfs.t${cyc}z.pgrbf$fh
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.pgrbf$fh'
   ;;
  pgiges) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.pgrbih$fh
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.pgrbif$fh
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.pgrbih$fh
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.pgrbif$fh
   $GETGES_NWG/$envir/gfs.$day/gfs.t${cyc}z.pgrbif$fh
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.pgrbif$fh'
   ;;
  pgbgm6) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.pgrbh$fhm6
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.pgrbf$fhm6
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.pgrbh$fhm6
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.pgrbf$fhm6
   $GETGES_NWG/$envir/gfs.$day/gfs.t${cyc}z.pgrbf$fhm6
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.pgrbf$fhm6'
   ;;
  pgigm6) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.pgrbih$fhm6
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.pgrbif$fhm6
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.pgrbih$fhm6
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.pgrbif$fhm6
   $GETGES_NWG/$envir/gfs.$day/gfs.t${cyc}z.pgrbif$fhm6
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.pgrbif$fhm6'
   ;;
  pgbgm3) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.pgrbh$fhm3
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.pgrbf$fhm3
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.pgrbh$fhm3
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.pgrbf$fhm3
   $GETGES_NWG/$envir/gfs.$day/gfs.t${cyc}z.pgrbf$fhm3
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.pgrbf$fhm3'
   ;;
  pgigm3) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.pgrbih$fhm3
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.pgrbif$fhm3
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.pgrbih$fhm3
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.pgrbif$fhm3
   $GETGES_NWG/$envir/gfs.$day/gfs.t${cyc}z.pgrbif$fhm3
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.pgrbif$fhm3'
   ;;
  pgbgp3) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.pgrbh$fhp3
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.pgrbf$fhp3
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.pgrbh$fhp3
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.pgrbf$fhp3
   $GETGES_NWG/$envir/gfs.$day/gfs.t${cyc}z.pgrbf$fhp3
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.pgrbf$fhp3'
   ;;
  pg2ges) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.pgrb2.0p25.f0$fh
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.pgrb2.0p25.f0$fh
   $GETGES_NWG/$envir/gfs.$day/gfs.t${cyc}z.pgrb2.0p25.f0$fh
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.pgrb2.0p25.f0$fh'
   ;;
  pg2gm6) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.pgrb2.0p25.f0$fhm6
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.pgrb2.0p25.f0$fhm6
   $GETGES_NWG/$envir/gfs.$day/gfs.t${cyc}z.pgrb2.0p25.f0$fhm6
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.pgrb2.0p25.f0$fhm6'
   ;;
  pg2gm3) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.pgrb2.0p25.f0$fhm3
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.pgrb2.0p25.f0$fhm3
   $GETGES_NWG/$envir/gfs.$day/gfs.t${cyc}z.pgrb2.0p25.f0$fhm3
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.pgrb2.0p25.f0$fhm3'
   ;;
  pg2gp3) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.pgrb2.0p25.f0$fhp3
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.pgrb2.0p25.f0$fhp3
   $GETGES_NWG/$envir/gfs.$day/gfs.t${cyc}z.pgrb2.0p25.f0$fhp3
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.pgrb2.0p25.f0$fhp3'
   ;;
  sigcur) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.sf$fh
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.sf$fh
   $GETGES_NWG/$envir/gfs.$day/gfs.t${cyc}z.sf$fh
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.sf$fh'
   getlist00='
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.sanl
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.sanl
   $GETGES_NWG/$envir/gfs.$day/gfs.t${cyc}z.sanl
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.sanl'
   fhbeg=00
   ;;
  sfccur) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.bf$fh
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.bf$fh
   $GETGES_NWG/$envir/gfs.$day/gfs.t${cyc}z.bf$fh
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.bf$fh'
   getlist00='
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.sfcanl
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.sfcanl
   $GETGES_NWG/$envir/gfs.$day/gfs.t${cyc}z.sfcanl
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.sfcanl'
   fhbeg=00
   ;;
  pgbcur) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.pgrbh$fh
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.pgrbf$fh
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.pgrbh$fh
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.pgrbf$fh
   $GETGES_NWG/$envir/gfs.$day/gfs.t${cyc}z.pgrbf$fh
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.pgrbf$fh'
   fhbeg=00
   ;;
  pgicur) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.pgrbih$fh
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.pgrbif$fh
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.pgrbih$fh
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.pgrbif$fh
   $GETGES_NWG/$envir/gfs.$day/gfs.t${cyc}z.pgrbif$fh
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.pgrbif$fh'
   fhbeg=00
   ;;
  prepqc) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.prepbufr
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.prepbufr
   $GETGES_NWG/$envir/gfs.$day/gfs.t${cyc}z.prepbufr
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.prepbufr'
   fhbeg=00
   fhend=00
   ;;
  tcvg12) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.syndata.tcvitals.tm00
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.syndata.tcvitals.tm00
   $GETGES_NWG/$envir/gfs.$day/gfs.t${cyc}z.syndata.tcvitals.tm00
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.syndata.tcvitals.tm00'
   fhbeg=12
   fhend=12
   ;;
  tcvges) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.syndata.tcvitals.tm00
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.syndata.tcvitals.tm00
   $GETGES_NWG/$envir/gfs.$day/gfs.t${cyc}z.syndata.tcvitals.tm00
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.syndata.tcvitals.tm00'
   fhbeg=06
   fhend=06
   ;;
  tcvitl) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.syndata.tcvitals.tm00
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.syndata.tcvitals.tm00
   $GETGES_NWG/$envir/gfs.$day/gfs.t${cyc}z.syndata.tcvitals.tm00
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.syndata.tcvitals.tm00'
   fhbeg=00
   fhend=00
   ;;
  icegrb) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.engicegrb
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.engicegrb
   $GETGES_NWG/$envir/gfs.$day/gfs.t${cyc}z.engicegrb
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.engicegrb'
   fhbeg=00
   fhinc=06
   ;;
  icegri) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.engicegrb.index
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.engicegrb.index
   $GETGES_NWG/$envir/gfs.$day/gfs.t${cyc}z.engicegrb.index
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.engicegrb.index'
   fhbeg=00
   fhinc=06
   ;;
  snogrb) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.snogrb
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.snogrb
   $GETGES_NWG/$envir/gfs.$day/gfs.t${cyc}z.snogrb
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.snogrb'
   fhbeg=00
   fhinc=06
   ;;
  snogrb_high) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.snogrb_t574
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.snogrb_t382
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.snogrb_t574
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.snogrb_t382
   $GETGES_NWG/$envir/gfs.$day/gfs.t${cyc}z.snogrb_t574
   $GETGES_NWG/$envir/gfs.$day/gfs.t${cyc}z.snogrb_t382
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.snogrb_t574 
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.snogrb_t382'
   fhbeg=00
   fhinc=06
   ;;
  snogrb_382) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.snogrb_t382
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.snogrb_t382
   $GETGES_NWG/$envir/gfs.$day/gfs.t${cyc}z.snogrb_t382
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.snogrb_t382'
   fhbeg=00
   fhinc=06
   ;;
  snogrb_574) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.snogrb_t574
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.snogrb_t574
   $GETGES_NWG/$envir/gfs.$day/gfs.t${cyc}z.snogrb_t574
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.snogrb_t574'
   fhbeg=00
   fhinc=06
   ;;
  snogri) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.snogrb.index
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.snogrb.index
   $GETGES_NWG/$envir/gfs.$day/gfs.t${cyc}z.snogrb.index
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.snogrb.index'
   fhbeg=00
   fhinc=06
   ;;
  sstgrb) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.sstgrb
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.sstgrb
   $GETGES_NWG/$envir/gfs.$day/gfs.t${cyc}z.sstgrb
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.sstgrb'
   fhbeg=00
   fhinc=06
   ;;
  sstgri) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.sstgrb.index
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.sstgrb.index
   $GETGES_NWG/$envir/gfs.$day/gfs.t${cyc}z.sstgrb.index
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.sstgrb.index'
   fhbeg=00
   fhinc=06
   ;;
 esac

# Low resolution production
elif [[ $netwk = global && $resol = low ]];then
 case $typef in
  sigges) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas2.t${cyc}z.sf$fh
   $GETGES_COM/gfs/$envir/gdas.$day/gdas2.t${cyc}z.sf$fh
   $GETGES_NWG/$envir/mrf.$day/drf01.t${cyc}z.sf$fh
   $GETGES_COM/mrf/$envir/mrf.$day/drf01.t${cyc}z.sf$fh'
   ;;
  siggm3) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas2.t${cyc}z.sf$fhm3
   $GETGES_COM/gfs/$envir/gdas.$day/gdas2.t${cyc}z.sf$fhm3
   $GETGES_NWG/$envir/mrf.$day/drf01.t${cyc}z.sf$fhm3
   $GETGES_COM/mrf/$envir/mrf.$day/drf01.t${cyc}z.sf$fhm3'
   ;;
  siggm2) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas2.t${cyc}z.sf$fhm2
   $GETGES_COM/gfs/$envir/gdas.$day/gdas2.t${cyc}z.sf$fhm2
   $GETGES_NWG/$envir/mrf.$day/drf01.t${cyc}z.sf$fhm2
   $GETGES_COM/mrf/$envir/mrf.$day/drf01.t${cyc}z.sf$fhm2'
   ;;
  siggm1) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas2.t${cyc}z.sf$fhm1
   $GETGES_COM/gfs/$envir/gdas.$day/gdas2.t${cyc}z.sf$fhm1
   $GETGES_NWG/$envir/mrf.$day/drf01.t${cyc}z.sf$fhm1
   $GETGES_COM/mrf/$envir/mrf.$day/drf01.t${cyc}z.sf$fhm1'
   ;;
  siggp1) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas2.t${cyc}z.sf$fhp1
   $GETGES_COM/gfs/$envir/gdas.$day/gdas2.t${cyc}z.sf$fhp1
   $GETGES_NWG/$envir/mrf.$day/drf01.t${cyc}z.sf$fhp1
   $GETGES_COM/mrf/$envir/mrf.$day/drf01.t${cyc}z.sf$fhp1'
   ;;
  siggp2) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas2.t${cyc}z.sf$fhp2
   $GETGES_COM/gfs/$envir/gdas.$day/gdas2.t${cyc}z.sf$fhp2
   $GETGES_NWG/$envir/mrf.$day/drf01.t${cyc}z.sf$fhp2
   $GETGES_COM/mrf/$envir/mrf.$day/drf01.t${cyc}z.sf$fhp2'
   ;;
  siggp3) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas2.t${cyc}z.sf$fhp3
   $GETGES_COM/gfs/$envir/gdas.$day/gdas2.t${cyc}z.sf$fhp3
   $GETGES_NWG/$envir/mrf.$day/drf01.t${cyc}z.sf$fhp3
   $GETGES_COM/mrf/$envir/mrf.$day/drf01.t${cyc}z.sf$fhp3'
   ;;
  sfcges) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas2.t${cyc}z.bf$fh
   $GETGES_COM/gfs/$envir/gdas.$day/gdas2.t${cyc}z.bf$fh
   $GETGES_NWG/$envir/mrf.$day/drf01.t${cyc}z.bf$fh
   $GETGES_COM/mrf/$envir/mrf.$day/drf01.t${cyc}z.bf$fh'
   ;;
  sfcgm3) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas2.t${cyc}z.bf$fhm3
   $GETGES_COM/gfs/$envir/gdas.$day/gdas2.t${cyc}z.bf$fhm3
   $GETGES_NWG/$envir/mrf.$day/drf01.t${cyc}z.bf$fhm3
   $GETGES_COM/mrf/$envir/mrf.$day/drf01.t${cyc}z.bf$fhm3'
   ;;
  sfcgm2) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas2.t${cyc}z.bf$fhm2
   $GETGES_COM/gfs/$envir/gdas.$day/gdas2.t${cyc}z.bf$fhm2
   $GETGES_NWG/$envir/mrf.$day/drf01.t${cyc}z.bf$fhm2
   $GETGES_COM/mrf/$envir/mrf.$day/drf01.t${cyc}z.bf$fhm2'
   ;;
  sfcgm1) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas2.t${cyc}z.bf$fhm1
   $GETGES_COM/gfs/$envir/gdas.$day/gdas2.t${cyc}z.bf$fhm1
   $GETGES_NWG/$envir/mrf.$day/drf01.t${cyc}z.bf$fhm1
   $GETGES_COM/mrf/$envir/mrf.$day/drf01.t${cyc}z.bf$fhm1'
   ;;
  sfcgp1) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas2.t${cyc}z.bf$fhp1
   $GETGES_COM/gfs/$envir/gdas.$day/gdas2.t${cyc}z.bf$fhp1
   $GETGES_NWG/$envir/mrf.$day/drf01.t${cyc}z.bf$fhp1
   $GETGES_COM/mrf/$envir/mrf.$day/drf01.t${cyc}z.bf$fhp1'
   ;;
  sfcgp2) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas2.t${cyc}z.bf$fhp2
   $GETGES_COM/gfs/$envir/gdas.$day/gdas2.t${cyc}z.bf$fhp2
   $GETGES_NWG/$envir/mrf.$day/drf01.t${cyc}z.bf$fhp2
   $GETGES_COM/mrf/$envir/mrf.$day/drf01.t${cyc}z.bf$fhp2'
   ;;
  sfcgp3) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas2.t${cyc}z.bf$fhp3
   $GETGES_COM/gfs/$envir/gdas.$day/gdas2.t${cyc}z.bf$fhp3
   $GETGES_NWG/$envir/mrf.$day/drf01.t${cyc}z.bf$fhp3
   $GETGES_COM/mrf/$envir/mrf.$day/drf01.t${cyc}z.bf$fhp3'
   ;;
  biascr) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas2.t${cyc}z.abias
   $GETGES_COM/gfs/$envir/gdas.$day/gdas2.t${cyc}z.abias
   $GETGES_NWG/$envir/mrf.$day/drf01.t${cyc}z.abias
   $GETGES_COM/mrf/$envir/mrf.$day/drf01.t${cyc}z.abias'
   fhbeg=06
   fhinc=06
   ;;
  satang) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas2.t${cyc}z.satang
   $GETGES_COM/gfs/$envir/gdas.$day/gdas2.t${cyc}z.satang
   $GETGES_NWG/$envir/mrf.$day/drf01.t${cyc}z.satang
   $GETGES_COM/mrf/$envir/mrf.$day/drf01.t${cyc}z.satang'
   fhbeg=06
   fhinc=06
   ;;
  satcnt) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas2.t${cyc}z.satcnt
   $GETGES_COM/gfs/$envir/gdas.$day/gdas2.t${cyc}z.satcnt
   $GETGES_NWG/$envir/mrf.$day/drf01.t${cyc}z.satcnt
   $GETGES_COM/mrf/$envir/mrf.$day/drf01.t${cyc}z.satcnt'
   fhbeg=06
   fhinc=06
   ;;
  gesfil) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas2.t${cyc}z.gesfile
   $GETGES_COM/gfs/$envir/gdas.$day/gdas2.t${cyc}z.gesfile
   $GETGES_NWG/$envir/mrf.$day/drf01.t${cyc}z.gesfile
   $GETGES_COM/mrf/$envir/mrf.$day/drf01.t${cyc}z.gesfile'
   fhbeg=00
   fhend=00
   ;;
  sfgges) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.sfluxgrbf$fh
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.sfluxgrbf$fh
   $GETGES_NWG/$envir/gfs.$day/gfs.t${cyc}z.sfluxgrbf$fh
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.sfluxgrbf$fh'
   ;;
  pgbges) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas2.t${cyc}z.pgrbf$fh
   $GETGES_COM/gfs/$envir/gdas.$day/gdas2.t${cyc}z.pgrbf$fh
   $GETGES_NWG/$envir/mrf.$day/drf01.t${cyc}z.pgrbf$fh
   $GETGES_COM/mrf/$envir/mrf.$day/drf01.t${cyc}z.pgrbf$fh'
   ;;
  pgiges) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas2.t${cyc}z.pgrbif$fh
   $GETGES_COM/gfs/$envir/gdas.$day/gdas2.t${cyc}z.pgrbif$fh
   $GETGES_NWG/$envir/mrf.$day/drf01.t${cyc}z.pgrbif$fh
   $GETGES_COM/mrf/$envir/mrf.$day/drf01.t${cyc}z.pgrbif$fh'
   ;;
  pgbgm6) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas2.t${cyc}z.pgrbf$fhm6
   $GETGES_COM/gfs/$envir/gdas.$day/gdas2.t${cyc}z.pgrbf$fhm6
   $GETGES_NWG/$envir/mrf.$day/drf01.t${cyc}z.pgrbf$fhm6
   $GETGES_COM/mrf/$envir/mrf.$day/drf01.t${cyc}z.pgrbf$fhm6'
   ;;
  pgigm6) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas2.t${cyc}z.pgrbif$fhm6
   $GETGES_COM/gfs/$envir/gdas.$day/gdas2.t${cyc}z.pgrbif$fhm6
   $GETGES_NWG/$envir/mrf.$day/drf01.t${cyc}z.pgrbif$fhm6
   $GETGES_COM/mrf/$envir/mrf.$day/drf01.t${cyc}z.pgrbif$fhm6'
   ;;
  pgbgm3) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas2.t${cyc}z.pgrbf$fhm3
   $GETGES_COM/gfs/$envir/gdas.$day/gdas2.t${cyc}z.pgrbf$fhm3
   $GETGES_NWG/$envir/mrf.$day/drf01.t${cyc}z.pgrbf$fhm3
   $GETGES_COM/mrf/$envir/mrf.$day/drf01.t${cyc}z.pgrbf$fhm3'
   ;;
  pgigm3) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas2.t${cyc}z.pgrbif$fhm3
   $GETGES_COM/gfs/$envir/gdas.$day/gdas2.t${cyc}z.pgrbif$fhm3
   $GETGES_NWG/$envir/mrf.$day/drf01.t${cyc}z.pgrbif$fhm3
   $GETGES_COM/mrf/$envir/mrf.$day/drf01.t${cyc}z.pgrbif$fhm3'
   ;;
  pgbgp3) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas2.t${cyc}z.pgrbf$fhp3
   $GETGES_COM/gfs/$envir/gdas.$day/gdas2.t${cyc}z.pgrbf$fhp3
   $GETGES_NWG/$envir/mrf.$day/drf01.t${cyc}z.pgrbf$fhp3
   $GETGES_COM/mrf/$envir/mrf.$day/drf01.t${cyc}z.pgrbf$fhp3'
   ;;
  pgigp3) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas2.t${cyc}z.pgrbif$fhp3
   $GETGES_COM/gfs/$envir/gdas.$day/gdas2.t${cyc}z.pgrbif$fhp3
   $GETGES_NWG/$envir/mrf.$day/drf01.t${cyc}z.pgrbif$fhp3
   $GETGES_COM/mrf/$envir/mrf.$day/drf01.t${cyc}z.pgrbif$fhp3'
   ;;
  pg2ges) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.pgrb2.0p25.f0$fh
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.pgrb2.0p25.f0$fh
   $GETGES_NWG/$envir/gfs.$day/gfs.t${cyc}z.pgrb2.0p25.f0$fh
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.pgrb2.0p25.f0$fh'
   ;;
  pg2gm6) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.pgrb2.0p25.f0$fhm6
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.pgrb2.0p25.f0$fhm6
   $GETGES_NWG/$envir/gfs.$day/gfs.t${cyc}z.pgrb2.0p25.f0$fhm6
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.pgrb2.0p25.f0$fhm6'
   ;;
  pg2gm3) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.pgrb2.0p25.f0$fhm3
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.pgrb2.0p25.f0$fhm3
   $GETGES_NWG/$envir/gfs.$day/gfs.t${cyc}z.pgrb2.0p25.f0$fhm3
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.pgrb2.0p25.f0$fhm3'
   ;;
  pg2gp3) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.pgrb2.0p25.f0$fhp3
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.pgrb2.0p25.f0$fhp3
   $GETGES_NWG/$envir/gfs.$day/gfs.t${cyc}z.pgrb2.0p25.f0$fhp3
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.pgrb2.0p25.f0$fhp3'
   ;;
  sigcur) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas2.t${cyc}z.sf$fh
   $GETGES_COM/gfs/$envir/gdas.$day/gdas2.t${cyc}z.sf$fh
   $GETGES_NWG/$envir/mrf.$day/drf01.t${cyc}z.sf$fh
   $GETGES_COM/mrf/$envir/mrf.$day/drf01.t${cyc}z.sf$fh'
   getlist00='
   $GETGES_NWG/$envir/gdas.$day/gdas2.t${cyc}z.sanl
   $GETGES_COM/gfs/$envir/gdas.$day/gdas2.t${cyc}z.sanl
   $GETGES_NWG/$envir/mrf.$day/drf01.t${cyc}z.sanl
   $GETGES_COM/mrf/$envir/mrf.$day/drf01.t${cyc}z.sanl'
   fhbeg=00
   ;;
  sfccur) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas2.t${cyc}z.bf$fh
   $GETGES_COM/gfs/$envir/gdas.$day/gdas2.t${cyc}z.bf$fh
   $GETGES_NWG/$envir/mrf.$day/drf01.t${cyc}z.bf$fh
   $GETGES_COM/mrf/$envir/mrf.$day/drf01.t${cyc}z.bf$fh'
   getlist00='
   $GETGES_NWG/$envir/gdas.$day/gdas2.t${cyc}z.sfcanl
   $GETGES_COM/gfs/$envir/gdas.$day/gdas2.t${cyc}z.sfcanl
   $GETGES_NWG/$envir/mrf.$day/drf01.t${cyc}z.sfcanl
   $GETGES_COM/mrf/$envir/mrf.$day/drf01.t${cyc}z.sfcanl'
   fhbeg=00
   ;;
  pgbcur) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas2.t${cyc}z.pgrbf$fh
   $GETGES_COM/gfs/$envir/gdas.$day/gdas2.t${cyc}z.pgrbf$fh
   $GETGES_NWG/$envir/mrf.$day/drf01.t${cyc}z.pgrbf$fh
   $GETGES_COM/mrf/$envir/mrf.$day/drf01.t${cyc}z.pgrbf$fh'
   fhbeg=00
   ;;
  pgicur) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas2.t${cyc}z.pgrbif$fh
   $GETGES_COM/gfs/$envir/gdas.$day/gdas2.t${cyc}z.pgrbif$fh
   $GETGES_NWG/$envir/mrf.$day/drf01.t${cyc}z.pgrbif$fh
   $GETGES_COM/mrf/$envir/mrf.$day/drf01.t${cyc}z.pgrbif$fh'
   fhbeg=00
   ;;
 esac

# Any resolution production
elif [[ $netwk = global && $resol = any ]];then
 case $typef in
  sigges) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.sf$fh
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.sf$fh
   $GETGES_NWG/$envir/gfs.$day/gfs.t${cyc}z.sf$fh
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.sf$fh'
   ;;
  siggm3) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.sf$fhm3
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.sf$fhm3
   $GETGES_NWG/$envir/gfs.$day/gfs.t${cyc}z.sf$fhm3
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.sf$fhm3'
   ;;
  siggm2) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.sf$fhm2
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.sf$fhm2
   $GETGES_NWG/$envir/gfs.$day/gfs.t${cyc}z.sf$fhm2
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.sf$fhm2'
   ;;
  siggm1) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.sf$fhm1
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.sf$fhm1
   $GETGES_NWG/$envir/gfs.$day/gfs.t${cyc}z.sf$fhm1
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.sf$fhm1'
   ;;
  siggp1) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.sf$fhp1
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.sf$fhp1
   $GETGES_NWG/$envir/gfs.$day/gfs.t${cyc}z.sf$fhp1
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.sf$fhp1'
   ;;
  siggp2) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.sf$fhp2
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.sf$fhp2
   $GETGES_NWG/$envir/gfs.$day/gfs.t${cyc}z.sf$fhp2
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.sf$fhp2'
   ;;
  siggp3) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.sf$fhp3
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.sf$fhp3
   $GETGES_NWG/$envir/gfs.$day/gfs.t${cyc}z.sf$fhp3
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.sf$fhp3'
   ;;
  sfcges) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.bf$fh
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.bf$fh
   $GETGES_NWG/$envir/gfs.$day/gfs.t${cyc}z.bf$fh
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.bf$fh'
   ;;
  sfcgm3) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.bf$fhm3
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.bf$fhm3
   $GETGES_NWG/$envir/gfs.$day/gfs.t${cyc}z.bf$fhm3
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.bf$fhm3'
   ;;
  sfcgm2) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.bf$fhm2
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.bf$fhm2
   $GETGES_NWG/$envir/gfs.$day/gfs.t${cyc}z.bf$fhm2
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.bf$fhm2'
   ;;
  sfcgm1) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.bf$fhm1
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.bf$fhm1
   $GETGES_NWG/$envir/gfs.$day/gfs.t${cyc}z.bf$fhm1
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.bf$fhm1'
   ;;
  sfcgp1) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.bf$fhp1
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.bf$fhp1
   $GETGES_NWG/$envir/gfs.$day/gfs.t${cyc}z.bf$fhp1
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.bf$fhp1'
   ;;
  sfcgp2) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.bf$fhp2
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.bf$fhp2
   $GETGES_NWG/$envir/gfs.$day/gfs.t${cyc}z.bf$fhp2
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.bf$fhp2'
   ;;
  sfcgp3) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.bf$fhp3
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.bf$fhp3
   $GETGES_NWG/$envir/gfs.$day/gfs.t${cyc}z.bf$fhp3
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.bf$fhp3'
   ;;
  biascr) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.abias
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.abias
   $GETGES_NWG/$envir/gfs.$day/gfs.t${cyc}z.abias
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.abias'
   fhbeg=06
   fhinc=06
   ;;
  satang) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.satang
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.satang
   $GETGES_NWG/$envir/gfs.$day/gfs.t${cyc}z.satang
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.satang'
   fhbeg=06
   fhinc=06
   ;;
  satcnt) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.satcnt
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.satcnt
   $GETGES_NWG/$envir/gfs.$day/gfs.t${cyc}z.satcnt
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.satcnt'
   fhbeg=06
   fhinc=06
   ;;
  gesfil) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.gesfile
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.gesfile
   $GETGES_NWG/$envir/gfs.$day/gfs.t${cyc}z.gesfile
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.gesfile'
   fhbeg=00
   fhend=00
   ;;
  sfgges) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.sfluxgrbf$fh
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.sfluxgrbf$fh
   $GETGES_NWG/$envir/gfs.$day/gfs.t${cyc}z.sfluxgrbf$fh
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.sfluxgrbf$fh'
   ;;
  pgbges) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.pgrbh$fh
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.pgrbf$fh
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.pgrbh$fh
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.pgrbf$fh
   $GETGES_NWG/$envir/gfs.$day/gfs.t${cyc}z.pgrbf$fh
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.pgrbf$fh'
   ;;
  pgiges) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.pgrbih$fh
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.pgrbif$fh
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.pgrbih$fh
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.pgrbif$fh
   $GETGES_NWG/$envir/gfs.$day/gfs.t${cyc}z.pgrbif$fh
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.pgrbif$fh'
   ;;
  pgbgm6) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.pgrbh$fhm6
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.pgrbf$fhm6
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.pgrbh$fhm6
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.pgrbf$fhm6
   $GETGES_NWG/$envir/gfs.$day/gfs.t${cyc}z.pgrbf$fhm6
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.pgrbf$fhm6'
   ;;
  pgigm6) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.pgrbih$fhm6
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.pgrbif$fhm6
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.pgrbih$fhm6
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.pgrbif$fhm6
   $GETGES_NWG/$envir/gfs.$day/gfs.t${cyc}z.pgrbif$fhm6
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.pgrbif$fhm6'
   ;;
  pgbgm3) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.pgrbh$fhm3
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.pgrbf$fhm3
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.pgrbh$fhm3
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.pgrbf$fhm3
   $GETGES_NWG/$envir/gfs.$day/gfs.t${cyc}z.pgrbf$fhm3
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.pgrbf$fhm3'
   ;;
  pgigm3) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.pgrbih$fhm3
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.pgrbif$fhm3
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.pgrbih$fhm3
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.pgrbif$fhm3
   $GETGES_NWG/$envir/gfs.$day/gfs.t${cyc}z.pgrbif$fhm3
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.pgrbif$fhm3'
   ;;
  pgbgp3) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.pgrbh$fhp3
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.pgrbf$fhp3
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.pgrbh$fhp3
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.pgrbf$fhp3
   $GETGES_NWG/$envir/gfs.$day/gfs.t${cyc}z.pgrbf$fhp3
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.pgrbf$fhp3'
   ;;
  pgigp3) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.pgrbih$fhp3
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.pgrbif$fhp3
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.pgrbih$fhp3
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.pgrbif$fhp3
   $GETGES_NWG/$envir/gfs.$day/gfs.t${cyc}z.pgrbif$fhp3
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.pgrbif$fhp3'
   ;;
  pg2ges) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.pgrb2.0p25.f0$fh
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.pgrb2.0p25.f0$fh
   $GETGES_NWG/$envir/gfs.$day/gfs.t${cyc}z.pgrb2.0p25.f0$fh
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.pgrb2.0p25.f0$fh'
   ;;
  pg2gm6) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.pgrb2.0p25.f0$fhm6
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.pgrb2.0p25.f0$fhm6
   $GETGES_NWG/$envir/gfs.$day/gfs.t${cyc}z.pgrb2.0p25.f0$fhm6
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.pgrb2.0p25.f0$fhm6'
   ;;
  pg2gm3) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.pgrb2.0p25.f0$fhm3
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.pgrb2.0p25.f0$fhm3
   $GETGES_NWG/$envir/gfs.$day/gfs.t${cyc}z.pgrb2.0p25.f0$fhm3
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.pgrb2.0p25.f0$fhm3'
   ;;
  pg2gp3) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.pgrb2.0p25.f0$fhp3
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.pgrb2.0p25.f0$fhp3
   $GETGES_NWG/$envir/gfs.$day/gfs.t${cyc}z.pgrb2.0p25.f0$fhp3
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.pgrb2.0p25.f0$fhp3'
   ;;
  sigcur) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.sf$fh
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.sf$fh
   $GETGES_NWG/$envir/gfs.$day/gfs.t${cyc}z.sf$fh
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.sf$fh'
   getlist00='
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.sanl
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.sanl
   $GETGES_NWG/$envir/gfs.$day/gfs.t${cyc}z.sanl
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.sanl'
   fhbeg=00
   ;;
  sfccur) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.bf$fh
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.bf$fh
   $GETGES_NWG/$envir/gfs.$day/gfs.t${cyc}z.bf$fh
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.bf$fh'
   getlist00='
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.sfcanl
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.sfcanl
   $GETGES_NWG/$envir/gfs.$day/gfs.t${cyc}z.sfcanl
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.sfcanl'
   fhbeg=00
   ;;
  pgbcur) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.pgrbh$fh
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.pgrbf$fh
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.pgrbh$fh
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.pgrbf$fh
   $GETGES_NWG/$envir/gfs.$day/gfs.t${cyc}z.pgrbf$fh
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.pgrbf$fh'
   fhbeg=00
   ;;
  pgicur) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.pgrbih$fh
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.pgrbif$fh
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.pgrbih$fh
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.pgrbif$fh
   $GETGES_NWG/$envir/gfs.$day/gfs.t${cyc}z.pgrbif$fh
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.pgrbif$fh'
   fhbeg=00
   ;;
  prepqc) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.prepbufr
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.prepbufr
   $GETGES_NWG/$envir/gfs.$day/gfs.t${cyc}z.prepbufr
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.prepbufr'
   fhbeg=00
   fhend=00
   ;;
  tcvg12) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.syndata.tcvitals.tm00
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.syndata.tcvitals.tm00
   $GETGES_NWG/$envir/gfs.$day/gfs.t${cyc}z.syndata.tcvitals.tm00
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.syndata.tcvitals.tm00'
   fhbeg=12
   fhend=12
   ;;
  tcvges) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.syndata.tcvitals.tm00
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.syndata.tcvitals.tm00
   $GETGES_NWG/$envir/gfs.$day/gfs.t${cyc}z.syndata.tcvitals.tm00
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.syndata.tcvitals.tm00'
   fhbeg=06
   fhend=06
   ;;
  tcvitl) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.syndata.tcvitals.tm00
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.syndata.tcvitals.tm00
   $GETGES_NWG/$envir/gfs.$day/gfs.t${cyc}z.syndata.tcvitals.tm00
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.syndata.tcvitals.tm00'
   fhbeg=00
   fhend=00
   ;;
  icegrb) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.engicegrb
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.engicegrb
   $GETGES_NWG/$envir/gfs.$day/gfs.t${cyc}z.engicegrb
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.engicegrb'
   fhbeg=00
   fhinc=06
   ;;
  icegri) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.engicegrb.index
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.engicegrb.index
   $GETGES_NWG/$envir/gfs.$day/gfs.t${cyc}z.engicegrb.index
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.engicegrb.index'
   fhbeg=00
   fhinc=06
   ;;
  snogrb) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.snogrb
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.snogrb
   $GETGES_NWG/$envir/gfs.$day/gfs.t${cyc}z.snogrb
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.snogrb'
   fhbeg=00
   fhinc=06
   ;;
  snogrb_high) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.snogrb_t574
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.snogrb_t382
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.snogrb_t574
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.snogrb_t382
   $GETGES_NWG/$envir/gfs.$day/gfs.t${cyc}z.snogrb_t574
   $GETGES_NWG/$envir/gfs.$day/gfs.t${cyc}z.snogrb_t382
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.snogrb_t574 
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.snogrb_t382'
   fhbeg=00
   fhinc=06
   ;;
  snogrb_382) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.snogrb_t382
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.snogrb_t382
   $GETGES_NWG/$envir/gfs.$day/gfs.t${cyc}z.snogrb_t382
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.snogrb_t382'
   fhbeg=00
   fhinc=06
   ;;
  snogrb_574) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.snogrb_t574
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.snogrb_t574
   $GETGES_NWG/$envir/gfs.$day/gfs.t${cyc}z.snogrb_t574
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.snogrb_t574'
   fhbeg=00
   fhinc=06
   ;;
  snogri) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.snogrb.index
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.snogrb.index
   $GETGES_NWG/$envir/gfs.$day/gfs.t${cyc}z.snogrb.index
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.snogrb.index'
   fhbeg=00
   fhinc=06
   ;;
  sstgrb) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.sstgrb
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.sstgrb
   $GETGES_NWG/$envir/gfs.$day/gfs.t${cyc}z.sstgrb
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.sstgrb'
   fhbeg=00
   fhinc=06
   ;;
  sstgri) geslist='
   $GETGES_NWG/$envir/gdas.$day/gdas1.t${cyc}z.sstgrb.index
   $GETGES_COM/gfs/$envir/gdas.$day/gdas1.t${cyc}z.sstgrb.index
   $GETGES_NWG/$envir/gfs.$day/gfs.t${cyc}z.sstgrb.index
   $GETGES_COM/gfs/$envir/gfs.$day/gfs.t${cyc}z.sstgrb.index'
   fhbeg=00
   fhinc=06
   ;;
 esac

# Early nam-32 resolution
elif [[ $netwk = namopl && $resol = namopl ]];then
 fhbeg=03
 fhinc=03
 fhend=12
 case $typef in
  restrt) geslist='
   $GETGES_NWG/$envir/nam.$day/nam.t${cyc}z.restrt$fh.tm00'
   ;;
 esac
fi

# Global parallel
if [[ $envir = dump || $envir = pr? ]];then
 fhend=384
 if [[ $netwk = global ]];then
  case $typef in
   sigges) geslist='
    $GETGES_GLO/$envir/sigf$fh.gdas.$id
    $GETGES_GLO/$envir/sigf$fh.gfs.$id'
    ;;
   siggm3) geslist='
    $GETGES_GLO/$envir/sigf$fhm3.gdas.$id
    $GETGES_GLO/$envir/sigf$fhm3.gfs.$id'
    ;;
   siggm2) geslist='
    $GETGES_GLO/$envir/sigf$fhm2.gdas.$id
    $GETGES_GLO/$envir/sigf$fhm2.gfs.$id'
    ;;
   siggm1) geslist='
    $GETGES_GLO/$envir/sigf$fhm1.gdas.$id
    $GETGES_GLO/$envir/sigf$fhm1.gfs.$id'
    ;;
   siggp1) geslist='
    $GETGES_GLO/$envir/sigf$fhp1.gdas.$id
    $GETGES_GLO/$envir/sigf$fhp1.gfs.$id'
    ;;
   siggp2) geslist='
    $GETGES_GLO/$envir/sigf$fhp2.gdas.$id
    $GETGES_GLO/$envir/sigf$fhp2.gfs.$id'
    ;;
   siggp3) geslist='
    $GETGES_GLO/$envir/sigf$fhp3.gdas.$id
    $GETGES_GLO/$envir/sigf$fhp3.gfs.$id'
    ;;
   sfcges) geslist='
    $GETGES_GLO/$envir/sfcf$fh.gdas.$id
    $GETGES_GLO/$envir/sfcf$fh.gfs.$id'
    ;;
   sfcgm3) geslist='
    $GETGES_GLO/$envir/sfcf$fhm3.gdas.$id
    $GETGES_GLO/$envir/sfcf$fhm3.gfs.$id'
    ;;
   sfcgm2) geslist='
    $GETGES_GLO/$envir/sfcf$fhm2.gdas.$id
    $GETGES_GLO/$envir/sfcf$fhm2.gfs.$id'
    ;;
   sfcgm1) geslist='
    $GETGES_GLO/$envir/sfcf$fhm1.gdas.$id
    $GETGES_GLO/$envir/sfcf$fhm1.gfs.$id'
    ;;
   sfcgp1) geslist='
    $GETGES_GLO/$envir/sfcf$fhp1.gdas.$id
    $GETGES_GLO/$envir/sfcf$fhp1.gfs.$id'
    ;;
   sfcgp2) geslist='
    $GETGES_GLO/$envir/sfcf$fhp2.gdas.$id
    $GETGES_GLO/$envir/sfcf$fhp2.gfs.$id'
    ;;
   sfcgp3) geslist='
    $GETGES_GLO/$envir/sfcf$fhp3.gdas.$id
    $GETGES_GLO/$envir/sfcf$fhp3.gfs.$id'
    ;;
   biascr) geslist='
    $GETGES_GLO/$envir/biascr.gdas.$id
    $GETGES_GLO/$envir/biascr.gfs.$id'
    fhbeg=06
    fhinc=06
    ;;
   satang) geslist='
    $GETGES_GLO/$envir/satang.gdas.$id
    $GETGES_GLO/$envir/satang.gfs.$id'
    fhbeg=06
    fhinc=06
    ;;
   satcnt) geslist='
    $GETGES_GLO/$envir/satcnt.gdas.$id
    $GETGES_GLO/$envir/satcnt.gfs.$id'
    fhbeg=06
    fhinc=06
    ;;
   gesfil) geslist='
    $GETGES_GLO/$envir/gesfile.gdas.$id
    $GETGES_GLO/$envir/gesfile.gfs.$id'
    fhbeg=00
    fhend=00
    ;;
   pgbges) geslist='
    $GETGES_GLO/$envir/pgbf$fh.gdas.$id
    $GETGES_GLO/$envir/pgbf$fh.gfs.$id'
    ;;
   pgbgm6) geslist='
    $GETGES_GLO/$envir/pgbf$fhm6.gdas.$id
    $GETGES_GLO/$envir/pgbf$fhm6.gfs.$id'
    ;;
   pgbgm3) geslist='
    $GETGES_GLO/$envir/pgbf$fhm3.gdas.$id
    $GETGES_GLO/$envir/pgbf$fhm3.gfs.$id'
    ;;
   pgbgp3) geslist='
    $GETGES_GLO/$envir/pgbf$fhp3.gdas.$id
    $GETGES_GLO/$envir/pgbf$fhp3.gfs.$id'
    ;;
   sigcur) geslist='
    $GETGES_GLO/$envir/sigf$fh.gdas.$id
    $GETGES_GLO/$envir/sigf$fh.gfs.$id'
    getlist00='
    $GETGES_GLO/$envir/siganl.gdas.$id
    $GETGES_GLO/$envir/siganl.gfs.$id'
    fhbeg=00
    ;;
   sfccur) geslist='
    $GETGES_GLO/$envir/sfcf$fh.gdas.$id
    $GETGES_GLO/$envir/sfcf$fh.gfs.$id'
    getlist00='
    $GETGES_GLO/$envir/sfcanl.gdas.$id
    $GETGES_GLO/$envir/sfcanl.gfs.$id'
    fhbeg=00
    ;;
   pgbcur) geslist='
    $GETGES_GLO/$envir/pgbf$fh.gdas.$id
    $GETGES_GLO/$envir/pgbf$fh.gfs.$id'
    fhbeg=00
    ;;
   prepqc) geslist='
    $GETGES_GLO/$envir/prepqc.gdas.$id
    $GETGES_GLO/$envir/prepqc.gfs.$id'
    fhbeg=00
    fhend=00
    ;;
   tcvg12) geslist='
    $GETGES_GLO/$envir/tcvitl.gdas.$id
    $GETGES_GLO/$envir/tcvitl.gfs.$id'
    fhbeg=12
    fhend=12
    ;;
   tcvges) geslist='
    $GETGES_GLO/$envir/tcvitl.gdas.$id
    $GETGES_GLO/$envir/tcvitl.gfs.$id'
    fhbeg=06
    fhend=06
    ;;
   tcvitl) geslist='
    $GETGES_GLO/$envir/tcvitl.gdas.$id
    $GETGES_GLO/$envir/tcvitl.gfs.$id'
    fhbeg=00
    fhend=00
    ;;
   icegrb) geslist='
    $GETGES_GLO/$envir/icegrb.gdas.$id
    $GETGES_GLO/$envir/icegrb.gfs.$id'
    fhbeg=00
    fhinc=06
    ;;
   snogrb) geslist='
    $GETGES_GLO/$envir/snogrb.gdas.$id
    $GETGES_GLO/$envir/snogrb.gfs.$id'
    fhbeg=00
    fhinc=06
    ;;
   sstgrb) geslist='
    $GETGES_GLO/$envir/sstgrb.gdas.$id
    $GETGES_GLO/$envir/sstgrb.gfs.$id'
    fhbeg=00
    fhinc=06
    ;;
  esac
 else
  case $typef in
   sigges) geslist='
    $GETGES_GLO/$envir/sigf$fh.$netwk.$id'
    ;;
   siggm3) geslist='
    $GETGES_GLO/$envir/sigf$fhm3.$netwk.$id'
    ;;
   siggm2) geslist='
    $GETGES_GLO/$envir/sigf$fhm2.$netwk.$id'
    ;;
   siggm1) geslist='
    $GETGES_GLO/$envir/sigf$fhm1.$netwk.$id'
    ;;
   siggp1) geslist='
    $GETGES_GLO/$envir/sigf$fhp1.$netwk.$id'
    ;;
   siggp2) geslist='
    $GETGES_GLO/$envir/sigf$fhp2.$netwk.$id'
    ;;
   siggp3) geslist='
    $GETGES_GLO/$envir/sigf$fhp3.$netwk.$id'
    ;;
   sfcges) geslist='
    $GETGES_GLO/$envir/sfcf$fh.$netwk.$id'
    ;;
   sfcgm3) geslist='
    $GETGES_GLO/$envir/sfcf$fhm3.$netwk.$id'
    ;;
   sfcgm2) geslist='
    $GETGES_GLO/$envir/sfcf$fhm2.$netwk.$id'
    ;;
   sfcgm1) geslist='
    $GETGES_GLO/$envir/sfcf$fhm1.$netwk.$id'
    ;;
   sfcgp1) geslist='
    $GETGES_GLO/$envir/sfcf$fhp1.$netwk.$id'
    ;;
   sfcgp2) geslist='
    $GETGES_GLO/$envir/sfcf$fhp2.$netwk.$id'
    ;;
   sfcgp3) geslist='
    $GETGES_GLO/$envir/sfcf$fhp3.$netwk.$id'
    ;;
   biascr) geslist='
    $GETGES_GLO/$envir/biascr.$netwk.$id'
    fhbeg=06
    fhinc=06
    ;;
   satang) geslist='
    $GETGES_GLO/$envir/satang.$netwk.$id'
    fhbeg=06
    fhinc=06
    ;;
   satcnt) geslist='
    $GETGES_GLO/$envir/satcnt.$netwk.$id'
    fhbeg=06
    fhinc=06
    ;;
   gesfil) geslist='
    $GETGES_GLO/$envir/gesfile.$netwk.$id'
    fhbeg=00
    fhend=00
    ;;
   pgbges) geslist='
    $GETGES_GLO/$envir/pgbf$fh.$netwk.$id'
    ;;
   pgbgm6) geslist='
    $GETGES_GLO/$envir/pgbf$fhm6.$netwk.$id'
    ;;
   pgbgm3) geslist='
    $GETGES_GLO/$envir/pgbf$fhm3.$netwk.$id'
    ;;
   pgbgp3) geslist='
    $GETGES_GLO/$envir/pgbf$fhp3.$netwk.$id'
    ;;
   sigcur) geslist='
    $GETGES_GLO/$envir/sigf$fh.$netwk.$id'
    getlist00='
    $GETGES_GLO/$envir/siganl.$netwk.$id'
    fhbeg=00
    ;;
   sfccur) geslist='
    $GETGES_GLO/$envir/sfcf$fh.$netwk.$id'
    getlist00='
    $GETGES_GLO/$envir/sfcanl.$netwk.$id'
    fhbeg=00
    ;;
   pgbcur) geslist='
    $GETGES_GLO/$envir/pgbf$fh.$netwk.$id'
    fhbeg=00
    ;;
   prepqc) geslist='
    $GETGES_GLO/$envir/prepqc.$netwk.$id'
    fhbeg=00
    fhend=00
    ;;
   tcvg12) geslist='
    $GETGES_GLO/$envir/tcvitl.$netwk.$id'
    fhbeg=12
    fhend=12
    ;;
   tcvges) geslist='
    $GETGES_GLO/$envir/tcvitl.$netwk.$id'
    fhbeg=06
    fhend=06
    ;;
   tcvitl) geslist='
    $GETGES_GLO/$envir/tcvitl.$netwk.$id'
    fhbeg=00
    fhend=00
    ;;
   icegrb) geslist='
    $GETGES_GLO/$envir/icegrb.$netwk.$id'
    fhbeg=00
    fhinc=06
    ;;
   snogrb) geslist='
    $GETGES_GLO/$envir/snogrb.$netwk.$id'
    fhbeg=00
    fhinc=06
    ;;
   sstgrb) geslist='
    $GETGES_GLO/$envir/sstgrb.$netwk.$id'
    fhbeg=00
    fhinc=06
    ;;
  esac
 fi
fi

#-------------------------------------------------------------------------------
# Check validity of options.
if [[ $fhour != any ]];then
  fhbeg=$fhour
  fhend=$fhour
fi
if [[ $valid -lt 20000000 ]];then
 valid=20$valid
 echo '************************************************************' >&2
 echo '* CAUTION: A 2-digit year was converted to a 4-digit year. *' >&2
 echo '*          Please use full a 4-digit year in this utility. *' >&2
 echo '************************************************************' >&2
elif [[ $valid -lt 100000000 ]];then
 valid=19$valid
 echo '************************************************************' >&2
 echo '* CAUTION: A 2-digit year was converted to a 4-digit year. *' >&2
 echo '*          Please use full a 4-digit year in this utility. *' >&2
 echo '************************************************************' >&2
fi
if [[ $($NDATE 0 $valid 2>/dev/null) != $valid ]];then
 echo getges.sh: invalid date $valid >&2
 exit 2
fi
if [[ -z $geslist ]];then
 echo getges.sh: filetype $typef or resolution $resol not recognized >&2
 exit 2
fi

#-------------------------------------------------------------------------------
# Loop until guess is found.
fh=$fhbeg
while [[ $fh -le $fhend ]];do
 ((fhm6=10#$fh-6))
 [[ $fhm6 -lt 10 && $fhm6 -ge 0 ]]&&fhm6=0$fhm6
 ((fhm3=10#$fh-3))
 [[ $fhm3 -lt 10 && $fhm3 -ge 0 ]]&&fhm3=0$fhm3
 ((fhm2=10#$fh-2))
 [[ $fhm2 -lt 10 && $fhm2 -ge 0 ]]&&fhm2=0$fhm2
 ((fhm1=10#$fh-1))
 [[ $fhm1 -lt 10 && $fhm1 -ge 0 ]]&&fhm1=0$fhm1
 ((fhp1=10#$fh+1))
 [[ $fhp1 -lt 10 ]]&&fhp1=0$fhp1
 ((fhp2=10#$fh+2))
 [[ $fhp2 -lt 10 ]]&&fhp2=0$fhp2
 ((fhp3=10#$fh+3))
 [[ $fhp3 -lt 10 ]]&&fhp3=0$fhp3
 id=$($NDATE -$fh $valid)
 typeset -L8 day=$id
 typeset -R2 cyc=$id
 eval list=\$getlist$fh
 [[ -z $list ]]&&list=${geslist}
 for gestest in $list;do
  eval ges=$gestest
  [[ $quiet = NO ]]&&echo Checking: $ges >&2
  [[ -r $ges ]]&&break 2
 done
 fh=$((10#$fh+10#$fhinc))
 [[ $fh -lt 10 ]]&&fh=0$fh
done
if [[ $fh -gt $fhend ]];then
 echo getges.sh: unable to find $netwk.$envir.$typef.$resol.$valid >&2
 exit 8
fi

#-------------------------------------------------------------------------------
# Either copy guess to a file or write guess name to standard output.
if [[ -z "$gfile" ]];then
 echo $ges
 exit $?
else
 cp $ges $gfile
 exit $?
fi
