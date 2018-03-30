#! /bin/bash
###############################################################
# < next few lines under version control, D O  N O T  E D I T >
# $Date: 2017-10-08 16:02:04 +0000 (Sun, 08 Oct 2017) $
# $Revision: 98185 $
# $Author: fanglin.yang@noaa.gov $
# $Id: fcst.sh 98185 2017-10-08 16:02:04Z fanglin.yang@noaa.gov $
###############################################################

###############################################################
## Author: Fanglin Yang   Org: NCEP/EMC  Date: October 2016
##         Rahul Mahajan  Org: NCEP/EMC  Date: April 2017

## Abstract:
## Model forecast driver script
## EXPDIR : /full/path/to/config/files
## CDATE  : current analysis date (YYYYMMDDHH)
## CDUMP  : cycle name (gdas / gfs)
###############################################################

set -ex
eval $( $HOMEcrow/to_sh.py $CONFIG_YAML export:y scope:platform.general_env import:".*" )
eval $( $HOMEcrow/to_sh.py $CONFIG_YAML export:y scope:workflow.$TASK_PATH from:Inherit )
eval $( $HOMEcrow/to_sh.py $CONFIG_YAML export:y scope:workflow.$TASK_PATH from:shell_vars )
eval $( $HOMEcrow/to_sh.py $CONFIG_YAML export:y scope:workflow.$TASK_PATH bool:.true.,.false. from:true_false_vars )

###############################################################
# Set script and dependency variables
export DATA=$RUNDIR/$CDATE/$CDUMP/fcst
[[ -d $DATA ]] && rm -rf $DATA

cymd=$(echo $CDATE | cut -c1-8)
chh=$(echo  $CDATE | cut -c9-10)

export GDATE=$($NDATE -$assim_freq $CDATE)
gymd=$(echo $GDATE | cut -c1-8)
ghh=$(echo  $GDATE | cut -c9-10)

# Default warm_start is OFF
export warm_start=".false."

# If RESTART conditions exist; warm start the model
# Restart conditions for GFS cycle come from GDAS
rCDUMP=$CDUMP
[[ $CDUMP = "gfs" ]] && export rCDUMP="gdas"

if [ -f $ROTDIR/${rCDUMP}.$gymd/$ghh/RESTART/${cymd}.${chh}0000.coupler.res ]; then
    export warm_start=".true."
    if [ -f $ROTDIR/${CDUMP}.$cymd/$chh/${CDUMP}.t${chh}z.atminc.nc ]; then
        export read_increment=".true."
    else
        echo "WARNING: WARM START $CDUMP $CDATE WITHOUT READING INCREMENT!"
    fi
fi

# Forecast length for GFS forecast
if [ $CDUMP = "gfs" ]; then
    export FHMIN=$FHMIN_GFS
    export FHOUT=$FHOUT_GFS
    export FHMAX=$FHMAX_GFS
    export FHMAX_HF=$FHMAX_HF_GFS
    export FHOUT_HF=$FHOUT_HF_GFS
fi

###############################################################
# Run relevant exglobal script
$FORECASTSH
status=$?
[[ $status -ne 0 ]] && exit $status

###############################################################
# Convert model native history files to nemsio

export DATA=$ROTDIR/${CDUMP}.$cymd/$chh

if [ $CDUMP = "gdas" ]; then

   if [ $OUTPUT_GRID = 'cubed_sphere_grid' -o $QUILTING = ".false." ]; then
       # Regrid 6-tile output to global array in NEMSIO gaussian grid for DA
       $REGRID_NEMSIO_SH
       status=$?
       [[ $status -ne 0 ]] && exit $status
   fi

elif [ $CDUMP = "gfs" ]; then

   if [ $OUTPUT_GRID = 'cubed_sphere_grid' -o $QUILTING = ".false." ]; then
       # Remap 6-tile output to global array in NetCDF latlon
       $REMAPSH
       status=$?
       [[ $status -ne 0 ]] && exit $status
   fi

   if [ $WRITE_NEMSIOFILE = ".false." -o $QUILTING = ".false." ]; then
       # Convert NetCDF to nemsio
       $NC2NEMSIOSH
       status=$?
       [[ $status -ne 0 ]] && exit $status
   fi

fi

###############################################################
# Exit out cleanly
exit 0
