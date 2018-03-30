#!/bin/bash

module load prod_util

source_IC_dir=$1
destination=$2
cdate=$3

CMDCP='ln -s'
if [[ ! -z $4 ]]; then
 if [[ $4=="--copy" ]]; then
  CMDCP='cp'
 fi
fi

ncdate=`$NDATE 06 $cdate`
fh=${cdate:8}
nh=${ncdate:8}

sdate=`echo $cdate | cut -c1-8`

echo
echo "cdate: $cdate"
echo "ncdate: $ncdate"
echo "sdate: $sdate"
echo "fh: $fh"
echo "nh: $nh"
echo "CMDCP: $CMDCP"
echo

mem_files=`ls -d1 $source_IC_dir/enkf.gdas.$sdate/$fh/mem??? | rev | cut -d"/" -f-1 | rev`

for mem in $mem_files; do

  echo "mkdir -p $destination/enkf.gdas.$sdate/$fh/$mem/RESTART"
  mkdir -p $destination/enkf.gdas.$sdate/$fh/$mem/RESTART
  mkdir -p $destination/enkf.gdas.$sdate/$nh/$mem/RESTART

done

shopt -s extglob

for mem in $mem_files; do

  echo "$CMDCP $source_IC_dir/enkf.gdas.$sdate/$fh/$mem/RESTART/!(*.sfcanl_data.tile*) $destination/enkf.gdas.$sdate/$fh/$mem/RESTART"
  $CMDCP $source_IC_dir/enkf.gdas.$sdate/$fh/$mem/RESTART/!(*.sfcanl_data.tile*) $destination/enkf.gdas.$sdate/$fh/$mem/RESTART
  $CMDCP `ls -1 $source_IC_dir/enkf.gdas.$sdate/$nh/$mem/gdas.t${nh}z.abias* | grep -v _int`  $destination/enkf.gdas.$sdate/$fh/$mem
  $CMDCP $source_IC_dir/enkf.gdas.$sdate/$nh/$mem/gdas.t${nh}z.radstat $destination/enkf.gdas.$sdate/$fh/$mem
  $CMDCP $source_IC_dir/enkf.gdas.$sdate/$nh/$mem/RESTART/*.sfcanl_data.tile* $destination/enkf.gdas.$sdate/$nh/$mem/RESTART
  $CMDCP $source_IC_dir/enkf.gdas.$sdate/$nh/$mem/gdas.t${nh}z.atminc.nc $destination/enkf.gdas.$sdate/$nh/$mem

done

mkdir -p $destination/gdas.$sdate/$fh/RESTART
mkdir -p $destination/gdas.$sdate/$nh/RESTART

echo "$CMDCP $source_IC_dir/gdas.$sdate/$fh/RESTART/!(*.sfcanl_data.tile*) $destination/gdas.$sdate/$fh/RESTART"
$CMDCP $source_IC_dir/gdas.$sdate/$fh/RESTART/!(*.sfcanl_data.tile*) $destination/gdas.$sdate/$fh/RESTART
$CMDCP `ls -1 $source_IC_dir/gdas.$sdate/$nh/gdas.t${nh}z.abias* | grep -v _int`  $destination/gdas.$sdate/$fh
$CMDCP $source_IC_dir/gdas.$sdate/$nh/gdas.t${nh}z.radstat $destination/gdas.$sdate/$fh
$CMDCP $source_IC_dir/gdas.$sdate/$nh/RESTART/*.sfcanl_data.tile* $destination/gdas.$sdate/$nh/RESTART
$CMDCP $source_IC_dir/gdas.$sdate/$nh/gdas.t${nh}z.atminc.nc $destination/gdas.$sdate/$nh
