#!/bin/ksh
################################################################################
# UNIX Script Documentation Block
# Script name:         exglobal_fcst_nemsfv3gfs.sh.ecf
# Script description:  Runs a global FV3GFS model forecast
#
# Author:   Fanglin Yang       Org: NCEP/EMC       Date: 2016-11-15
# Abstract: This script runs a single GFS forecast with FV3 dynamical core.
#           This script is created based on a C-shell script that GFDL wrote
#           for the NGGPS Phase-II Dycore Comparison Project.
#
# Script history log:
# 2016-11-15  Fanglin Yang   First Version.
# 2017-02-09  Rahul Mahajan  Added warm start and restructured the code.
# 2017-03-10  Fanglin Yang   Updated for running forecast on Cray.
# 2017-03-24  Fanglin Yang   Updated to use NEMS FV3GFS with IPD4
# 2017-05-24  Rahul Mahajan  Updated for cycling with NEMS FV3GFS
# 2017-09-13  Fanglin Yang   Updated for using GFDL MP and Write Component
#
# $Id$
#
# Attributes:
#   Language: Portable Operating System Interface (POSIX) Shell
#   Machine: WCOSS-CRAY, Theia
################################################################################

#  Set environment.
VERBOSE=${VERBOSE:-"YES"}
if [ $VERBOSE = "YES" ] ; then
  echo $(date) EXECUTING $0 $* >&2
  set -x
fi

# This should be in the script that calls this script, not here
machine=${machine:-"WCOSS_C"}
machine=$(echo $machine | tr '[a-z]' '[A-Z]')
if [ $machine = "WCOSS_C" ] ; then
  . $MODULESHOME/init/sh 2>/dev/null
  PRGENV=${PRGENV:-intel}
  HUGEPAGES=${HUGEPAGES:-hugepages4M}
  module  unload prod_util iobuf PrgEnv-$PRGENV craype-$HUGEPAGES 2>/dev/null
  module  load   prod_util iobuf PrgEnv-$PRGENV craype-$HUGEPAGES 2>/dev/null
  module load intel/16.3.210 2>/dev/null
  module  use /usrx/local/dev/modulefiles
  export IOBUF_PARAMS=${IOBUF_PARAMS:-'*:size=8M:verbose'}
  export MPICH_GNI_COLL_OPT_OFF=${MPICH_GNI_COLL_OPT_OFF:-MPI_Alltoallv}
  export MKL_CBWR=AVX2
  module use /gpfs/hps3/emc/nems/noscrub/emc.nemspara/soft/modulefiles 2>/dev/null
  module load esmf/7.1.0bs34 2>/dev/null
elif [ $machine = "THEIA" ]; then
  . $MODULESHOME/init/sh 2>/dev/null
  module use /scratch4/NCEPDEV/nems/noscrub/emc.nemspara/soft/modulefiles 2>/dev/null
  module load esmf/7.1.0bs34 2>/dev/null
fi

# Directories.
pwd=$(pwd)
DATA=${DATA:-$( pwd -P )/fv3tmp$$}    # temporary running directory
SEND=${SEND:-"YES"}   #move final result to rotating directory
KEEPDATA=${KEEPDATA:-"NO"}
NTASKS_FV3=${NTASKS_FV3:-$npe_fv3}

#-------------------------------------------------------
set -ue
if [ ! -d $ROTDIR ]; then mkdir -p $ROTDIR; fi
if [ ! -d $DATA ]; then mkdir -p $DATA ;fi
mkdir -p $DATA/RESTART $DATA/INPUT
cd $DATA
set +ue

#-------------------------------------------------------
# member directory
if [ $MEMBER -lt 0 ]; then
  prefix=$CDUMP
  rprefix=$rCDUMP
  memchar=""
else
  prefix=enkf.$CDUMP
  rprefix=enkf.$rCDUMP
  memchar=mem$(printf %03i $MEMBER)
fi
cymd=$(echo $CDATE | cut -c1-8)
chh=$(echo  $CDATE | cut -c9-10)
memdir=$ROTDIR/${prefix}.$cymd/$chh/$memchar
if [ ! -d $memdir ]; then mkdir -p $memdir; fi

GDATE=$($NDATE -$assim_freq $CDATE)
gymd=$(echo $GDATE | cut -c1-8)
ghh=$(echo  $GDATE | cut -c9-10)
gmemdir=$ROTDIR/${rprefix}.$gymd/$ghh/$memchar

#-------------------------------------------------------
# initial conditions
increment_file=${increment_file:-$memdir/${CDUMP}.t${chh}z.atminc.nc}

if [ $warm_start = ".false." ]; then
  if [ -d $ICSDIR/$CDATE/$CDUMP/$CASE/INPUT ]; then
    $NCP $ICSDIR/$CDATE/$CDUMP/$CASE/INPUT/* $DATA/INPUT/.
  else
    for file in $memdir/INPUT/*.nc; do
      file2=$(echo $(basename $file))
      fsuf=$(echo $file2 | cut -c1-3)
      if [ $fsuf = "gfs" -o $fsuf = "sfc" ]; then
        $NLN $file $DATA/INPUT/$file2
      fi
    done
  fi
else
  if [ ${restart_test:-"NO"} = "YES" ]; then
    # start from the end of last forecast run
    $NLN $gmemdir/RESTART/* $DATA/INPUT/.
  else

    # Link all (except sfc_data) restart files from $gmemdir
    for file in $gmemdir/RESTART/${cymd}.${chh}0000.*.nc; do
      file2=$(echo $(basename $file))
      file2=$(echo $file2 | cut -d. -f3-) # remove the date from file
      fsuf=$(echo $file2 | cut -d. -f1)
      if [ $fsuf != "sfc_data" ]; then
         $NLN $file $DATA/INPUT/$file2
      fi
    done

    # Link sfcanl_data restart files from $memdir
    for file in $memdir/RESTART/${cymd}.${chh}0000.*.nc; do
      file2=$(echo $(basename $file))
      file2=$(echo $file2 | cut -d. -f3-) # remove the date from file
      fsufanl=$(echo $file2 | cut -d. -f1)
      if [ $fsufanl = "sfcanl_data" ]; then
        file2=$(echo $file2 | sed -e "s/sfcanl_data/sfc_data/g")
        $NLN $file $DATA/INPUT/$file2
      fi
    done

    # Handle coupler.res file for DA cycling
    if [ ${USE_COUPLER_RES:-"YES"} = "YES" ]; then
      # In DA, this is not really a "true restart",
      # and the model start time is the analysis time
      # The alternative is to replace
      # model start time with current model time in coupler.res
      file=$gmemdir/RESTART/${cymd}.${chh}0000.coupler.res
      file2=$(echo $(basename $file))
      file2=$(echo $file2 | cut -d. -f3-) # remove the date from file
      $NLN $file $DATA/INPUT/$file2
    fi

    if [ $read_increment = ".true." ]; then
      if [ -f $increment_file ]; then
        $NLN $increment_file $DATA/INPUT/fv3_increment.nc
      else
        read_increment=".false."
      fi
    fi
  fi
fi
nfiles=$(ls -1 $DATA/INPUT/* | wc -l)
if [ $nfiles -le 0 ]; then
  echo "Initial conditions must exist in $DATA/INPUT, ABORT!"
  exit 1
fi

#--------------------------------------------------------------------------
# Grid and orography data
for n in $(seq 1 $ntiles); do
  $NLN $FIX_FV3/$CASE/${CASE}_grid.tile${n}.nc     $DATA/INPUT/${CASE}_grid.tile${n}.nc
  $NLN $FIX_FV3/$CASE/${CASE}_oro_data.tile${n}.nc $DATA/INPUT/oro_data.tile${n}.nc
done
$NLN $FIX_FV3/$CASE/${CASE}_mosaic.nc  $DATA/INPUT/grid_spec.nc

# GFS standard input data

$NLN $FIX_AM/global_solarconstant_noaa_an.txt  $DATA/solarconstant_noaa_an.txt
$NLN $FIX_AM/global_o3prdlos.f77               $DATA/INPUT/global_o3prdlos.f77
$NLN $FIX_AM/global_sfc_emissivity_idx.txt     $DATA/sfc_emissivity_idx.txt

$NLN $FIX_AM/global_co2historicaldata_glob.txt $DATA/co2historicaldata_glob.txt
$NLN $FIX_AM/co2monthlycyc.txt                 $DATA/co2monthlycyc.txt
if [ $ICO2 -gt 0 ]; then
  for file in $(ls $FIX_AM/fix_co2_proj/global_co2historicaldata*) ; do
    $NLN $file $DATA/$(echo $(basename $file) | sed -e "s/global_//g")
  done
fi

$NLN $FIX_AM/global_climaeropac_global.txt     $DATA/aerosol.dat
if [ $IAER -gt 0 ] ; then
  for file in $(ls $FIX_AM/global_volcanic_aerosols*) ; do
    $NLN $file $DATA/$(echo $(basename $file) | sed -e "s/global_//g")
  done
fi

#------------------------------------------------------------------
# Namelists.

CROW_TO_SH="$HOMEcrow/to_sh.py $CONFIG_YAML scope:workflow.$TASK_PATH"

# Override stochastic physics seeds if requested:
if [ ${SET_STP_SEED:-"YES"} = "YES" ]; then
  ISEED_SKEB=$((CDATE*1000 + MEMBER*10 + 1))
  ISEED_SHUM=$((CDATE*1000 + MEMBER*10 + 2))
  ISEED_SPPT=$((CDATE*1000 + MEMBER*10 + 3))
  CROW_TO_SH="$CROW_TO_SH apply:ISEED_SKEB=$ISEED_SKEB apply:ISEED_SHUM=$ISEED_SHUM apply:ISEED_SPPT=$ISEED_SPPT"
fi

set -eu

# Build the FMS diag_table with the experiment name and date stamp:
pwd
ls -ld .
eval $( $CROW_TO_SH DIAG_TABLE=DIAG_TABLE )
$CROW_TO_SH expand:diag_table_header > ./diag_table
cat diag_table
cat $DIAG_TABLE >> ./diag_table

$NCP $DATA_TABLE  data_table
$NCP $FIELD_TABLE field_table

# NEMS and FV3 namelists:
$CROW_TO_SH expand:input_nml > ./input.nml
cat input.nml
$CROW_TO_SH expand:nems_configure > ./nems.configure
cat nems.configure
$CROW_TO_SH expand:model_configure > ./model_configure
cat model_configure

set +eu

#------------------------------------------------------------------
# setup the runtime environment and run the executable
cd $DATA
$NCP $FCSTEXECDIR/$FCSTEXEC $DATA/.
export OMP_NUM_THREADS=$NTHREADS_FV3
$APRUN_FV3 $DATA/$FCSTEXEC 1>&1 2>&2
export ERR=$?
export err=$ERR
$ERRSCRIPT || exit $err

#------------------------------------------------------------------
if [ $SEND = "YES" ]; then
  # Copy model output files
  cd $DATA
  if [ $QUILTING = ".true." -a $OUTPUT_GRID = "gaussian_grid" ]; then
    $NCP ${CDUMP}.t${chh}z.atm*.nemsio $memdir/.
    $NCP ${CDUMP}.t${chh}z.sfc*.nemsio $memdir/.
  else
    for n in $(seq 1 $ntiles); do
      for file in *.tile${n}.nc; do
        $NCP $file $memdir/.
      done
    done
  fi

  # Copy model restart files
  cd $DATA/RESTART
  mkdir -p $memdir/RESTART

  # Add time-stamp to restart files at FHMAX (this should be done inside the model)
  RDATE=$($NDATE +$FHMAX $CDATE)
  rymd=$(echo $RDATE | cut -c1-8)
  rhh=$(echo  $RDATE | cut -c9-10)
  for file in $(ls * | grep -v 0000); do
    $NMV $file ${rymd}.${rhh}0000.$file
  done

  # Only save restarts at single time in RESTART directory
  # Either at FHMAX or at first time in restart_interval
  if [ $restart_interval -eq 0 ]; then
    RDATE=$($NDATE +$FHMAX $CDATE)
  else
    RDATE=$($NDATE +$restart_interval $CDATE)
  fi
  rymd=$(echo $RDATE | cut -c1-8)
  rhh=$(echo  $RDATE | cut -c9-10)
  for file in ${rymd}.${rhh}0000.* ; do
    $NCP $file $memdir/RESTART/$file
  done

fi

#------------------------------------------------------------------
# Clean up before leaving
if [ $KEEPDATA = "NO" ]; then rm -rf $DATA; fi

#------------------------------------------------------------------
set +x
if [ $VERBOSE = "YES" ] ; then
  echo $(date) EXITING $0 with return code $err >&2
fi
exit 0
