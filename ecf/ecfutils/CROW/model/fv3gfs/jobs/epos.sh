#! /bin/bash
###############################################################
# < next few lines under version control, D O  N O T  E D I T >
# $Date: 2017-09-23 02:48:49 +0000 (Sat, 23 Sep 2017) $
# $Revision: 97753 $
# $Author: fanglin.yang@noaa.gov $
# $Id: epos.sh 97753 2017-09-23 02:48:49Z fanglin.yang@noaa.gov $
###############################################################

###############################################################
## Author: Rahul Mahajan  Org: NCEP/EMC  Date: April 2017

## Abstract:
## Ensemble post-processing driver script
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
cymd=$(echo $CDATE | cut -c1-8)
chh=$(echo  $CDATE | cut -c9-10)

export PREFIX="${CDUMP}.t${chh}z."
export SUFFIX=".nemsio"

export COMIN="$ROTDIR/enkf.$CDUMP.$cymd/$chh"
export COMOUT="$ROTDIR/enkf.$CDUMP.$cymd/$chh"
export DATA="$RUNDIR/$CDATE/$CDUMP/epos"
if [ ${KEEPDATA:-"NO"} = "NO" ] ; then rm -rf $DATA ; fi

export LEVS=$((LEVS-1))

###############################################################
# Run relevant exglobal script
$ENKFPOSTSH
status=$?
[[ $status -ne 0 ]] && exit $status

###############################################################
# Exit out cleanly
exit 0
