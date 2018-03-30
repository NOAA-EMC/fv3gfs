#!/bin/sh
##BSUB -J gfs_GEN_00
##BSUB -W 0:30
##BSUB -o /gpfs/hps/ptmp/Jiayi.Peng/com2/gfs_genesis_00.o%J
##BSUB -e /gpfs/hps/ptmp/Jiayi.Peng/com2/gfs_genesis_00.o%J
##BSUB -q "dev"
##BSUB -P "GEN-T2O"
##BSUB -M 1000
##BSUB -extsched 'CRAYLINUX[]'
##export NODES=1

date
export PS4=' $SECONDS + '
set -x

. $MODULESHOME/init/sh
module use /gpfs/hps/nco/ops/nwprod/modulefiles
module load prod_util
module load grib_util/1.0.3

module use  /opt/cray/alt-modulefiles
module load PrgEnv-intel
module load iobuf/2.0.5

module use /opt/cray/craype/default/alt-modulefiles
module load craype-haswell
module list

#export IOBUF_PARAMS="*:size=256M:count=4:verbose"
export IOBUF_PARAMS="*:size=32M:count=4:verbose"

export NWROOTGENESIS=${NWROOTGENESIS:-/gpfs/hps/emc/ensemble/save/Jiayi.Peng}
export COMDATEROOT=/gpfs/hps/nco/ops/com
#export COMROOTp1=/gpfs/tp1/nco/ops/com
export ens_tracker_ver=v2.0.1

export CDATE=${1:-?}
export CDUMP=${2:-?}
export COMROT=${3:-?}
export DATA=${4:-?}

export GESROOT=${COMROT}

#export APRNRELOC="time aprun -b -j1 -n1 -N1 -d24 -cc depth"
#export APRNGETTX="time aprun -q -j1 -n1 -N1 -d1 -cc depth "
export APRUNTRACK="aprun -j1 -n1 -N1 -d1"

export JYYYY=`echo ${CDATE} | cut -c1-4`
export PDY=`echo ${CDATE} | cut -c1-8`
export cyc=`echo ${CDATE} | cut -c9-10`
export cycle=t${cyc}z

mkdir -p $DATA
cd $DATA

mkdir -p ${ROTDIR}/logs/$CDATE
export jlogfile=${jlogfile:-${ROTDIR}/logs/$CDATE/genesis_tracker.log}

export SENDECF=${SENDECF:-NO}
export SENDCOM=${SENDCOM:-YES}
export SENDDBN=${SENDDBN:-NO}

####################################
# Specify Execution Areas
####################################
export HOMEens_tracker=${HOMEens_tracker:-${NWROOTGENESIS}/ens_tracker.${ens_tracker_ver}}
export EXECens_tracker=${EXECens_tracker:-$HOMEens_tracker/exec}
export FIXens_tracker=${FIXens_tracker:-$HOMEens_tracker/fix}
export USHens_tracker=${USHens_tracker:-$HOMEens_tracker/ush}
export SCRIPTens_tracker=${SCRIPTens_tracker:-$HOMEens_tracker/scripts}

##############################################
# Define COM directories
##############################################
#export COMINgfs=${COMINgfs:-${COMROOTp2}/gfs/prod/gfs.${PDY}}
#export COMINsyn=${COMINsyn:-${COMROOTp1}/arch/prod/syndat}
export COMINgfs=${COMINgfs:-$(compath.py gfs/prod/gfs.$PDY)}
export COMINsyn=${COMINsyn:-$(compath.py arch/prod/syndat)}

export COMIN=${COMIN:-${COMROT}}
export COMOUT=${COMOUT:-${COMROT}}

export COMINgenvit=${COMINgenvit:-${DATA}/genesis_vital_${JYYYY}}
export COMOUTgenvit=${COMOUTgenvit:-${DATA}/genesis_vital_${JYYYY}}

export gfspara=${gfspara:-${COMIN}}
#export gfspara=${gfspara:-/gpfs/hps/ptmp/emc.glopara/prtest}
#export gfspara=/ptmpd3/emc.glopara/pr4devbs15
#export gfspara=/ptmpp2/emc.glopara/pr4devbs12

mkdir -m 775 -p $COMOUT $COMOUTgenvit

msg="HAS BEGUN on `hostname`"

env

${SCRIPTens_tracker}/exgfs_tc_genesis_fv3gfs.sh
export err=$?; err_chk

msg="JOB COMPLETED NORMALLY"
postmsg "$jlogfile" "$msg"

##############################
# Remove the Temporary working directory
##############################
#rm -rf $DATA

date
