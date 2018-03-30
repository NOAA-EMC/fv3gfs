#! /bin/bash
###############################################################
# < next few lines under version control, D O  N O T  E D I T >
# $Date: 2017-08-16 21:42:24 +0000 (Wed, 16 Aug 2017) $
# $Revision: 96658 $
# $Author: fanglin.yang@noaa.gov $
# $Id: ecen.sh 96658 2017-08-16 21:42:24Z fanglin.yang@noaa.gov $
###############################################################

###############################################################
## Author: Rahul Mahajan  Org: NCEP/EMC  Date: April 2017

## Abstract:
## Ensemble recentering driver script
## EXPDIR : /full/path/to/config/files
## CDATE  : current analysis date (YYYYMMDDHH)
## CDUMP  : cycle name (gdas / gfs)
###############################################################

set -ex
eval $( $HOMEcrow/to_sh.py $CONFIG_YAML export:y scope:platform.general_env import:".*" )
eval $( $HOMEcrow/to_sh.py $CONFIG_YAML export:y scope:workflow.$TASK_PATH from:Inherit )
eval $( $HOMEcrow/to_sh.py $CONFIG_YAML export:y scope:workflow.$TASK_PATH from:shell_vars )

###############################################################
# Set script and dependency variables
export GDATE=$($NDATE -$assim_freq $CDATE)

cymd=$(echo $CDATE | cut -c1-8)
chh=$(echo  $CDATE | cut -c9-10)
gymd=$(echo $GDATE | cut -c1-8)
ghh=$(echo  $GDATE | cut -c9-10)

export APREFIX="${CDUMP}.t${chh}z."
export ASUFFIX=".nemsio"
export GPREFIX="${CDUMP}.t${ghh}z."
export GSUFFIX=".nemsio"

export COMIN="$ROTDIR/$CDUMP.$cymd/$chh"
export COMIN_ENS="$ROTDIR/enkf.$CDUMP.$cymd/$chh"
export COMIN_GES_ENS="$ROTDIR/enkf.$CDUMP.$gymd/$ghh"
export DATA="$RUNDIR/$CDATE/$CDUMP/ecen"
if [ ${KEEPDATA:-"NO"} = "NO" ] ; then rm -rf $DATA ; fi

###############################################################
# Run relevant exglobal script
$ENKFRECENSH
status=$?
[[ $status -ne 0 ]] && exit $status

###############################################################
# Exit out cleanly
exit 0
