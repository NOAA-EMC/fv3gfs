#! /bin/bash
###############################################################
# < next few lines under version control, D O  N O T  E D I T >
# $Date: 2017-10-23 21:23:33 +0000 (Mon, 23 Oct 2017) $
# $Revision: 98608 $
# $Author: fanglin.yang@noaa.gov $
# $Id: efcs.sh 98608 2017-10-23 21:23:33Z fanglin.yang@noaa.gov $
###############################################################

###############################################################
## Author: Rahul Mahajan  Org: NCEP/EMC  Date: April 2017

## Abstract:
## Ensemble forecast driver script
## EXPDIR : /full/path/to/config/files
## CDATE  : current analysis date (YYYYMMDDHH)
## CDUMP  : cycle name (gdas / gfs)
## ENSGRP : ensemble sub-group to make forecasts (1, 2, ...)
###############################################################

set -ex
eval $( $HOMEcrow/to_sh.py $CONFIG_YAML export:y scope:platform.general_env import:".*" )
eval $( $HOMEcrow/to_sh.py $CONFIG_YAML export:y scope:workflow.$TASK_PATH from:Inherit )
eval $( $HOMEcrow/to_sh.py $CONFIG_YAML export:y scope:workflow.$TASK_PATH from:shell_vars )
eval $( $HOMEcrow/to_sh.py $CONFIG_YAML export:y scope:workflow.$TASK_PATH bool:.true.,.false. from:true_false_vars )

###############################################################
# Set script and dependency variables
export CASE=$CASE_ENKF
export DATA=$RUNDIR/$CDATE/$CDUMP/efcs.grp$ENSGRP
[[ -d $DATA ]] && rm -rf $DATA

# Get ENSBEG/ENSEND from ENSGRP and NMEM_EFCSGRP
ENSEND=$((NMEM_EFCSGRP * ENSGRP))
ENSBEG=$((ENSEND - NMEM_EFCSGRP + 1))
export ENSBEG=$ENSBEG
export ENSEND=$ENSEND

cymd=$(echo $CDATE | cut -c1-8)
chh=$(echo  $CDATE | cut -c9-10)

export GDATE=$($NDATE -$assim_freq $CDATE)
gymd=$(echo $GDATE | cut -c1-8)
ghh=$(echo  $GDATE | cut -c9-10)

# Default warm_start is OFF
export warm_start=".false."

# If RESTART conditions exist; warm start the model
memchar="mem"$(printf %03i $ENSBEG)
if [ -f $ROTDIR/enkf.${CDUMP}.$gymd/$ghh/$memchar/RESTART/${cymd}.${chh}0000.coupler.res ]; then
    export warm_start=".true."
    if [ -f $ROTDIR/enkf.${CDUMP}.$cymd/$chh/$memchar/${CDUMP}.t${chh}z.atminc.nc ]; then
        export read_increment=".true."
    else
        echo "WARNING: WARM START $CDUMP $CDATE WITHOUT READING INCREMENT!"
    fi
fi

# Forecast length for EnKF forecast
export FHMIN=$FHMIN_ENKF
export FHOUT=$FHOUT_ENKF
export FHMAX=$FHMAX_ENKF

###############################################################
# Run relevant exglobal script
$ENKFFCSTSH
status=$?
[[ $status -ne 0 ]] && exit $status

###############################################################
# Double check the status of members in ENSGRP
EFCSGRP=$ROTDIR/enkf.${CDUMP}.$cymd/$chh/efcs.grp${ENSGRP}
if [ -f $EFCSGRP ]; then
    npass=$(grep "PASS" $EFCSGRP | wc -l)
else
    npass=0
fi
echo "$npass/$NMEM_EFCSGRP members successfull in efcs.grp$ENSGRP"
if [ $npass -ne $NMEM_EFCSGRP ]; then
    echo "ABORT!"
    cat $EFCSGRP
    exit 99
fi

###############################################################
# Exit out cleanly
exit 0
