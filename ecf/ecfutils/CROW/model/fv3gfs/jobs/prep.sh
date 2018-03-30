#! /bin/bash
###############################################################
# < next few lines under version control, D O  N O T  E D I T >
# $Date: 2017-10-30 18:48:54 +0000 (Mon, 30 Oct 2017) $
# $Revision: 98721 $
# $Author: fanglin.yang@noaa.gov $
# $Id: prep.sh 98721 2017-10-30 18:48:54Z fanglin.yang@noaa.gov $
###############################################################

###############################################################
## Author: Rahul Mahajan  Org: NCEP/EMC  Date: April 2017

## Abstract:
## Do prepatory tasks
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

export OPREFIX="${CDUMP}.t${chh}z."

export COMOUT="$ROTDIR/$CDUMP.$cymd/$chh"
[[ ! -d $COMOUT ]] && mkdir -p $COMOUT

# Do relocation
if [ $DO_RELOCATE = "YES" ]; then
    $DRIVE_RELOCATESH
    echo "RELOCATION IS TURNED OFF in FV3, DRIVE_RELOCATESH does not exist, ABORT!"
    status=1
    [[ $status -ne 0 ]] && exit $status
fi

# Generate prepbufr files from dumps or copy from OPS
if [ $DO_MAKEPREPBUFR = "YES" ]; then
    "$BASE_JOB"/drive_makeprepbufr.sh
    [[ $status -ne 0 ]] && exit $status
else
    $NCP $DMPDIR/$CDATE/$CDUMP/${OPREFIX}prepbufr               $COMOUT/${OPREFIX}prepbufr
    $NCP $DMPDIR/$CDATE/$CDUMP/${OPREFIX}prepbufr.acft_profiles $COMOUT/${OPREFIX}prepbufr.acft_profiles
    [[ $DONST = "YES" ]] && $NCP $DMPDIR/$CDATE/$CDUMP/${OPREFIX}nsstbufr $COMOUT/${OPREFIX}nsstbufr
fi

################################################################################
# Exit out cleanly
exit 0
