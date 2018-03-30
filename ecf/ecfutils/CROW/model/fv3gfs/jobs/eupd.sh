#! /bin/bash
###############################################################
# < next few lines under version control, D O  N O T  E D I T >
# $Date: 2017-09-23 02:48:49 +0000 (Sat, 23 Sep 2017) $
# $Revision: 97753 $
# $Author: fanglin.yang@noaa.gov $
# $Id: eupd.sh 97753 2017-09-23 02:48:49Z fanglin.yang@noaa.gov $
###############################################################

###############################################################
## Author: Rahul Mahajan  Org: NCEP/EMC  Date: April 2017

## Abstract:
## EnKF update driver script
## EXPDIR : /full/path/to/config/files
## CDATE  : current analysis date (YYYYMMDDHH)
## CDUMP  : cycle name (gdas / gfs)
###############################################################

set -ex
eval $( $HOMEcrow/to_sh.py $CONFIG_YAML export:y scope:platform.general_env import:".*" )
eval $( $HOMEcrow/to_sh.py $CONFIG_YAML export:y scope:workflow.$TASK_PATH from:Inherit )
eval $( $HOMEcrow/to_sh.py $CONFIG_YAML export:y scope:workflow.$TASK_PATH from:shell_vars )
set +e
###############################################################
# Set script and dependency variables
export GDATE=$($NDATE -$assim_freq $CDATE)

cymd=$(echo $CDATE | cut -c1-8)
chh=$(echo  $CDATE | cut -c9-10)
gymd=$(echo $GDATE | cut -c1-8)
ghh=$(echo  $GDATE | cut -c9-10)

export GPREFIX="${CDUMP}.t${ghh}z."
export GSUFFIX=".nemsio"
export APREFIX="${CDUMP}.t${chh}z."
export ASUFFIX=".nemsio"

export COMIN_GES_ENS="$ROTDIR/enkf.$CDUMP.$gymd/$ghh"
export COMOUT_ANL_ENS="$ROTDIR/enkf.$CDUMP.$cymd/$chh"
export DATA="$RUNDIR/$CDATE/$CDUMP/eupd"
if [ ${KEEPDATA:-"NO"} = "NO" ] ; then rm -rf $DATA ; fi

###############################################################
# Run relevant exglobal script
echo "RUN: $ENKFUPDSH"
$ENKFUPDSH
status=$?
[[ $status -ne 0 ]] && exit $status

###############################################################
# Exit out cleanly
exit 0
