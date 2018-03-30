#!/bin/ksh
set -x

##---------------------------------------------------------------------------
## Modified version of vsdbjob_submit.sh for use in NCEP/EMC GFS para_config 
## to do verification while forecast is running.
## Fanglin Yang, 01Jan2010
##---------------------------------------------------------------------------

## variables read in from vrfy.sh and/or para_config
export DATEST=${1:-20080701}                         ;#forecast starting date
export DATEND=${2:-20080801}                         ;#forecast ending date
export vlength=${3:-384}                             ;#forecast length in hour
export cycle=${4:-"00"}                              ;#forecast cycle
export exp1name=${5:-"pre13a"}                       ;#experiment names
export VSDB_START_DATE=${6:-$VSDB_START_DATE}        ;#map starting date
export anl_type=${7:-${anltype:-gfs}}                ;#analysis type for verification: gfs, gdas, ecmwf, manl or canl
export gfs_cyc=${8:-${gfs_cyc:-1}}                   ;#number of GFS cycles, 1-->00Z, 4-->00Z 06Z 12Z and 18Z        
export iauf00=${9:-${iauf00:-"NO"}}                  ;#set pgbf00=pgbanl for forecasts with IAU 

export exp1dir=${ARCDIR1:-/global/hires/glopara/archive} ;#online archive of current exp
export scppgb=${SCP_PGB:-"NO"}                       ;#whether of not to scp pgb files from CLIENT
export sfcvsdb=${sfcvsdb:-"YES"}                     ;#include the group of surface variables
export rundir0=${rundir:-$STMP/$LOGNAME/vsdb_exp}

##
##-------------------------------------------------------------------
##-------------------------------------------------------------------

MAKEVSDBDATA=${VSDB_STEP1:-NO}           ;#To create VSDB date

MAKEMAPS=${VSDB_STEP2:-NO}               ;#To make AC and RMS maps

CONUSPLOTS=${VSDB_STEP2:-NO}             ;#To make precip verification plots 

CONUSDATA=${VRFYPRCP:-NO}                ;#To compute precip threat skill scores

VRFYG2OBS=${VRFYG2OBS:-NO}               ;#To create grid2obs vsdb date             

#----------------------------------------------------------------------
export machine=${machine:-WCOSS}                                 ;#WCOSS, THEIA                 
export machine=$(echo $machine|tr '[a-z]' '[A-Z]')
export ACCOUNT=${ACCOUNT:-GFS-T2O}                               ;#ibm computer ACCOUNT task
export CUE2RUN=${CUE2RUN:-shared}                                ;#dev or devhigh or 1
export CUE2FTP=${CUE2FTP:-$CUE2RUNA}                             ;#queue for data transfer
export GROUP=${GROUP:-g01}                                       ;#account group       
export webhost=${webhost:-"emcrzdm.ncep.noaa.gov"}               ;#host for web display
export webhostid=${webhostid:-$LOGNAME}                          ;#id of webhost
export ftpdir=${WEBDIR:-/home/people/emc/www/htdocs/gmb/$webhostid}/vsdb
export doftp=${SEND2WEB:-"NO"}                                   ;#whether or not to sent maps to ftpdir
export vsdbsave=${vsdbsave:-/stmp/$LOGNAME/VSDB/vsdb_data}       ;#place where vsdb database is saved

chost=`echo $(hostname) |cut -c 1-1 `
chost2=`echo $(hostname) |cut -c 1-2 `

if [ $machine = THEIA ]; then
 export vsdbhome=${vsdbhome:-/scratch4/NCEPDEV/global/save/Fanglin.Yang/VRFY/vsdb} ;#script home, do not change
 export GNOSCRUB=${GNOSCRUB:-/scratch4/NCEPDEV/global/noscrub}        ;#archive directory
 export STMP=${STMP:-/scratch4/NCEPDEV/stmp3}                          ;#temporary directory
 export PTMP=${PTMP:-/scratch4/NCEPDEV/stmp3}                          ;#temporary directory

 export obdata=/scratch4/NCEPDEV/global/save/Fanglin.Yang/obdata      ;#observation data for making 2dmaps
 export gstat=/scratch4/NCEPDEV/global/noscrub/stat  ;#global stats directory
 export gfsvsdb=$gstat/vsdb_data                            ;#operational gfs vsdb database
 export canldir=$gstat/canl                                 ;#consensus analysis directory
 export ecmanldir=$gstat/ecm                                ;#ecmwf analysis directory
 export OBSPCP=$gstat/OBSPRCP                               ;#observed precip for verification
 export gfswgnedir=$gstat/wgne1                             ;#operational gfs precip QPF scores
 export gfsfitdir=$gstat/surufits                           ;#Suru operational model fit-to-obs database
 export gdas_prepbufr_arch=$gstat/prepbufr/gdas
 export ndasbufr_arch=$gstat/prepbufr/ndas
 export nambufr_arch=$gstat/prepbufr/nam
 export SUBJOB=$vsdbhome/bin/sub_theia                       ;#script for submitting batch jobs
 export CUE2FTP=service                                     ;#data transfer queue 
 export NWPROD=$vsdbhome/nwprod                             ;#common utilities and libs included in /nwprod
 export GRADSBIN=/apps/grads/2.0.1a/bin                     ;#GrADS executables
 export IMGCONVERT=/usr/bin/convert                         ;#image magic converter
 export FC=/apps/intel/composer_xe_2013_sp1.2.144/bin/intel64/ifort   ;#intel compiler
 export FFLAG="-O2 -convert big_endian -FR"                 ;#intel compiler options
 export APRUN=""
 export COMROTNCO=${COMROTNCO:-/scratch4/NCEPDEV/rstprod/com}
 export COMROTNAM=$COMROTNCO

elif [ $machine = JET ]; then
 export vsdbhome=${vsdbhome:-/pan2/projects/gnmip/Fanglin.Yang/VRFY/vsdb}   ;#script home, do not change
 export GNOSCRUB=${GNOSCRUB:-/pan2/projects/gnmip/$LOGNAME/noscrub} ;#temporary directory                  
 export STMP=${STMP:-/pan2/projects/gnmip/$LOGNAME/ptmp}            ;#temporary directory                          
 export PTMP=${PTMP:-/pan2/projects/gnmip/$LOGNAME/ptmp}            ;#temporary directory                          

 export obdata=/pan2/projects/gnmip/Fanglin.Yang/VRFY/obdata    ;#observation data for making 2dmaps
 export gstat=/pan2/projects/gnmip/Fanglin.Yang/VRFY/stat       ;#global stats directory              
 export gfsvsdb=$gstat/vsdb_data                            ;#operational gfs vsdb database
 export canldir=$gstat/canl                                 ;#consensus analysis directory
 export ecmanldir=$gstat/ecm                                ;#ecmwf analysis directory
 export OBSPCP=$gstat/OBSPRCP                               ;#observed precip for verification
 export gfswgnedir=$gstat/wgne1                             ;#operational gfs precip QPF scores
 export gfsfitdir=$gstat/surufits                           ;#Suru operational model fit-to-obs database
 export gdas_prepbufr_arch=$gstat/prepbufr/gdas
 export SUBJOB=$vsdbhome/bin/sub_jet                        ;#script for submitting batch jobs
 export NWPROD=$vsdbhome/nwprod                             ;#common utilities and libs included in /nwprod
 export GRADSBIN=/opt/grads/2.0.a2//bin/grads               ;#GrADS executables       
 export IMGCONVERT=/usr/bin/convert                         ;#image magic converter
 export FC=/opt/intel/Compiler/11.1/072//bin/intel64/ifort  ;#intel compiler
 export FFLAG="-O2 -convert big_endian -FR"                 ;#intel compiler options
 export APRUN=""

elif [ $chost = t -o $machine = WCOSS ]; then
 export vsdbhome=${vsdbhome:-/global/save/Fanglin.Yang/VRFY/vsdb}    ;#script home, do not change
 export GNOSCRUB=${GNOSCRUB:-/global/noscrub}          ;#archive directory
 export STMP=${STMP:-/stmp}                            ;#temporary directory
 export PTMP=${PTMP:-/ptmp}                            ;#temporary directory

 export obdata=/global/save/Fanglin.Yang/obdata        ;#observation data for making 2dmaps
 export gstat=/global/noscrub/Fanglin.Yang/stat        ;#global stats directory
 export gfsvsdb=$gstat/vsdb_data                       ;#operational gfs vsdb database
 export canldir=$gstat/canl                            ;#consensus analysis directory
 export ecmanldir=$gstat/ecm                           ;#ecmwf analysis directory
 export OBSPCP=$gstat/OBSPRCP                          ;#observed precip for verification
 export gfswgnedir=$gstat/wgne1                        ;#operational gfs precip QPF scores
 export gfsfitdir=$gstat/surufits                      ;#Suru operational model fit-to-obs database
 export gdas_prepbufr_arch=/global/noscrub/Fanglin.Yang/prepbufr/gdas ;#ops gdas prepbufr archive
 export ndasbufr_arch=/global/noscrub/Fanglin.Yang/prepbufr/ndas
 export nambufr_arch=/global/noscrub/Fanglin.Yang/prepbufr/nam
 export SUBJOB=$vsdbhome/bin/sub_wcoss                 ;#script for submitting batch jobs
 export CUE2FTP=transfer                               ;#data transfer queue 
 export NWPROD=$vsdbhome/nwprod                        ;#common utilities and libs included in /nwprod
 export GRADSBIN=/usrx/local/GrADS/2.0.2/bin           ;#GrADS executables
 export IMGCONVERT=/usrx/local/ImageMagick/6.8.3-3/bin/convert ;#image magic converter
 export FC=/usrx/local/intel/composer_xe_2011_sp1.11.339/bin/intel64/ifort    ;#intel compiler
 export FFLAG="-O2 -convert big_endian -FR"            ;#fortran compiler options
 export APRUN=""
 export COMROTNCO=${COMROTNCO:-/gpfs/hps/nco/ops/com}
 export COMROTNAM=${COMROTNAM:-/com2}

elif [ $machine = WCOSS_C ]; then
 export vsdbhome=${vsdbhome:-/gpfs/hps3/emc/global/noscrub/Fanglin.Yang/VRFY/vsdb}    ;#script home, do not change
 export GNOSCRUB=${GNOSCRUB:-/gpfs/hps3/emc/global/noscrub}         ;#archive directory
 export STMP=${STMP:-/gpfs/hps3/stmp}                               ;#temporary directory
 export PTMP=${PTMP:-/gpfs/hps3/ptmp}                               ;#temporary directory

 export obdata=/gpfs/hps3/emc/global/noscrub/Fanglin.Yang/obdata    ;#observation data for making 2dmaps
 export gstat=/gpfs/hps3/emc/global/noscrub/Fanglin.Yang/stat        ;#global stats directory
 export gfsvsdb=$gstat/vsdb_data                       ;#operational gfs vsdb database
 export canldir=$gstat/canl                            ;#consensus analysis directory
 export ecmanldir=$gstat/ecm                           ;#ecmwf analysis directory
 export OBSPCP=$gstat/OBSPRCP                          ;#observed precip for verification
 export gfswgnedir=$gstat/wgne                         ;#operational gfs precip QPF scores
 export gfsfitdir=$gstat/surufits                      ;#Suru operational model fit-to-obs database
 export gdas_prepbufr_arch=/gpfs/hps3/emc/global/noscrub/Fanglin.Yang/prepbufr/gdas ;#ops gdas prepbufr archive
 export ndasbufr_arch=/gpfs/hps3/emc/global/noscrub/Fanglin.Yang/prepbufr/ndas
 export nambufr_arch=/gpfs/hps3/emc/global/noscrub/Fanglin.Yang/prepbufr/nam
 export SUBJOB=$vsdbhome/bin/sub_wcoss_c               ;#script for submitting batch jobs
 export CUE2FTP=dev_transfer                           ;#data transfer queue 
 export NWPROD=$vsdbhome/nwprod                        ;#common utilities and libs included in /nwprod
 export GRADSBIN=/gpfs/hps3/emc/global/noscrub/Fanglin.Yang/software/grads-2.1.a2/bin
 export IMGCONVERT=/usr/bin/convert                    ;#image magic converter
 export FC=/opt/intel/composer_xe_2015.3.187/bin/intel64/ifort 
 export FFLAG="-O2 -convert big_endian -FR"            ;#fortran compiler options
 export APRUN="aprun -n 1 -N 1 -j 1 -d 1"
 . $MODULESHOME/init/sh
  module load prod_envir
  export COMROTNCO=${COMROTNCO:-$COMROOT}
  export COMROTNAM=${COMROTNAM:-$COMROOTp2}
fi

if [ $gfs_cyc = 1 ]; then
 export vhrlist=${vhrlist:-"$cycle"}            ;#verification hours for each day
 export fcyclist="$cycle"                       ;#forecast cycles to be included in stats computation
 export cyc2runvsdb="$cycle"                    ;#cycle to run vrfy which will generate vsdb data for all cycles of the day
elif [ $gfs_cyc = 2 ]; then
 export vhrlist=${vhrlist:-"00 12 "}            ;#verification hours for each day
 export fcyclist="00 12"                        ;#forecast cycles to be included in stats computation
 export cyc2runvsdb=12                          ;#cycle to run vrfy which will generate vsdb data for all cycles of the day
elif [ $gfs_cyc = 4 ]; then
 export vhrlist=${vhrlist:-"00 06 12 18"}       ;#verification hours for each day
 export fcyclist="00 06 12 18"                  ;#forecast cycles to be included in stats computation
 export cyc2runvsdb=18                          ;#cycle to run vrfy which will generate vsdb data for all cycles of the day
else
 echo "gfs_cyc must be 1, 2 or 4, quit vsdbjob"                                          
 exit
fi

if [ $cycle != $cyc2runvsdb ]; then 
 MAKEVSDBDATA=NO 
 MAKEMAPS=NO 
 VRFYG2OBS=NO 
fi
if [ $cycle != 00 -a $cycle != 12 ]; then 
 CONUSPLOTS=NO
 CONUSDATA=NO
fi
 

### --------------------------------------------------------------
###   make vsdb database
      if [ $MAKEVSDBDATA = YES ] ; then
### --------------------------------------------------------------
export fcyclist="$fcyclist"                         ;#all fcst cycles to be included in verification
export expnlist=$exp1name                           ;#experiment names 
export expdlist=$exp1dir                            ;#exp online archive directories
export complist=$(hostname)                         ;#computers where experiments are run
export dumplist=".gfs."                             ;#file format pgb${asub}${fhr}${dump}${yyyymmdd}${cyc}

export anl_type=$anl_type                           ;#analysis type for verification: gfs, gdas or canl
export DATEST=$DATEST                               ;#verification starting date
export DATEND=$DATEND                               ;#verification ending date
export vlength=$vlength                             ;#forecast length in hour
export asub=${asub:-a}                              ;#string in pgb anal file after pgb, say, pgbanl, pgbhnl 
export fsub=${fsub:-f}                              ;#string in pgb fcsy file after pgb, say, pgbf06, pgbh06

if [ ! -d $vsdbhome ]; then
 echo "$vsdbhome does not exist "
 exit
fi
if [ ! -d $expdlist ]; then
 echo "$expdlist does not exist "
 exit
fi

export rundir=$rundir0/acrmse_stat
#export listvar1=fcyclist,vhrlist,expnlist,expdlist,complist,dumplist,DATEST,DATEND,vlength,rundir
#export listvar2=machine,anl_type,scppgb,sfcvsdb,canldir,ecmanldir,vsdbsave,vsdbhome,gd,NWPROD
#export listvar="$listvar1,$listvar2"

${vsdbhome}/verify_exp_step1.sh

### --------------------------------------------------------------
      fi                                       
### --------------------------------------------------------------


 
### --------------------------------------------------------------
###   make AC and RMSE maps            
      if [ $MAKEMAPS = YES ] ; then
### --------------------------------------------------------------
#
export mdlist=${mdlist:-"gfs $exp1name"}        ;#experiment names, up to 10                                     
export fcyclist="$fcyclist"                     ;#forecast cycles to show on map 
export DATEST=${VSDB_START_DATE:-$DATEST}       ;#map starting date  starting date to show on map
export DATEND=$DATEND                           ;#verification ending date to show on map
export vlength=$vlength                         ;#forecast length in hour to show on map
export maptop=${maptop:-10}                     ;#can be set to 10, 50 or 100 hPa for cross-section maps
export maskmiss=${maskmiss:-1}                  ;#remove missing data from all models to unify sample size, 0-->NO, 1-->Yes

set -A namelist $mdlist
export rundir=$rundir0/acrmse_map  

${vsdbhome}/verify_exp_step2.sh
### --------------------------------------------------------------
    fi
### --------------------------------------------------------------


### --------------------------------------------------------------
###   make CONUS precip plots
      if [ $CONUSPLOTS = YES ] ; then
### --------------------------------------------------------------
export expnlist=$mdlist                                             ;#experiment names, up to 6 
export expdlist=${expd_list:-"$exp1dir $exp1dir $exp1dir $exp1dir $exp1dir $exp1dir"}    ;#precip stats online archive dirs
export complist=${comp_list:-"$(hostname) $(hostname) $(hostname) $(hostname) $(hostname) $(hostname) "}  ;#computers where experiments are run

export cycle=$cycle                                       ;#cycle to make QPF plots 
export DATEST=$DATEST                                     ;#forecast starting date to show on map
export DATEND=$(echo $($NWPROD/util/exec/ndate -${VBACKUP_PRCP:-00} ${DATEND}00 ) |cut -c1-8 )
export rundir=$rundir0/rain_map  
export scrdir=${vsdbhome}/precip                  
export vhour=${vhr_rain:-${vhour:-180}}                                 ;#verification length in hour
                                                                                                                           
${scrdir}/plot_pcp.sh
### --------------------------------------------------------------
      fi
### --------------------------------------------------------------
                                                                                                                           

### --------------------------------------------------------------
###   compute precip threat score stats over CONUS
      if [ $CONUSDATA = YES ] ; then
### --------------------------------------------------------------
export cycle=$cycle                                 ;#cycle to generate QPF stats data
export expnlist=$exp1name                           ;#experiment names 
export expdlist=`dirname $COMROT`                   ;#exp online archive directories
export complist=$(hostname)                         ;#computers where experiments are run
export dumplist=".gfs."                             ;#file format pgb${asub}${fhr}${dump}${yyyymmdd}${cyc}
export DATEST=`$NWPROD/util/exec/ndate -${VBACKUP_PRCP:-00} ${DATEST}00 |cut -c 1-8 ` ;#verification starting date
export DATEND=`$NWPROD/util/exec/ndate -${VBACKUP_PRCP:-00} ${DATEND}00 |cut -c 1-8 ` ;#verification starting date

export ftyplist=${ftyplist:-"flxf"}                 ;#file types: pgbq or flxf
export dumplist=${dumplist:-".gfs."}                ;#file format ${ftyp}f${fhr}${dump}${yyyymmdd}${cyc}
export ptyplist=${ptyplist:-"PRATE"}                ;#precip types in GRIB: PRATE or APCP
export bucket=${bucket:-6}                          ;#accumulation bucket in hours. bucket=0 -- continuous accumulation
export fhout=6                                      ;#forecast output frequency in hours
export vhour=${vhr_rain:-${vhour:-180}}             ;#verification length in hour
export ARCDIR=${ARCDIR1:-$GNOSCRUB/$LOGNAME/archive} ;#directory to save stats data
export rundir=$rundir0/rain_stat  
export scrdir=${vsdbhome}/precip

#export listvar1=expnlist,expdlist,complist,ftyplist,dumplist,ptyplist,bucket,fhout,cyclist,vhour
#export listvar2=machine,DATEST,DATEND,ARCDIR,rundir,scrdir,OBSPCP,mapdir,scppgb,NWPROD
#export listvar="$listvar1,$listvar2"

${scrdir}/mkup_rain_stat.sh  
### --------------------------------------------------------------
      fi
### --------------------------------------------------------------


### --------------------------------------------------------------
###   make grid2obs vsdb database
      if [ $VRFYG2OBS = YES ] ; then
### --------------------------------------------------------------
export cyclist="$fcyclist"                  ;#all fcst cycles to be included in verification
export expnlist="$exp1name"                  ;#experiment names 
export expdlist="$exp1dir"                   ;#exp online archive directories
export complist="$(hostname)"               ;#computers where experiments are run
export dumplist=".gfs."                     ;#file format pgb${asub}${fhr}${dump}${yyyymmdd}${cyc}
export fhoutair="6"                         ;#forecast output frequency in hours for raobs vrfy
export fhoutsfc="3"                         ;#forecast output frequency in hours for sfc vrfy
export gdtype="3"                           ;#pgb file resolution, 2 for 2.5-deg and 3 for 1-deg
export vsdbsfc="YES"                        ;#run sfc verification
export vsdbair="YES"                        ;#run upper-air verification
if [ $vlength -ge 168 ]; then
 export vlength=168                          ;#forecast length in hour
else
 export vlength=$vlength                     ;#forecast length in hour
fi
export DATEST=`$NWPROD/util/exec/ndate -${VBACKUP_G2OBS:-00} ${DATEST}00 |cut -c 1-8 ` ;#verification starting date
export DATEND=`$NWPROD/util/exec/ndate -${VBACKUP_G2OBS:-00} ${DATEND}00 |cut -c 1-8 ` ;#verification ending date
export batch=YES
export rundir=$rundir0/grid2obs_stat  
export HPSSTAR=${HPSSTAR:-/u/Fanglin.Yang/bin/hpsstar}
export hpssdirlist=${hpsslist:-"/5year/NCEPDEV/emc-global/$LOGNAME/$machine"}
export runhpss=${runhpss:-NO}               ;#run hpsstar in batch mode if data are missing

if [ ! -d $vsdbhome ]; then
 echo "$vsdbhome does not exist "
 exit
fi
if [ ! -d $expdlist ]; then
 echo "$expdlist does not exist "
 exit
fi


#listvar1=vsdbhome,vsdbsave,cyclist,expnlist,expdlist,dumplist,complist,fhoutair,fhoutsfc,vsdbsfc,vsdbair,gdtype,vlength
#listvar2=NWPROD,SUBJOB,ACCOUNT,CUE2RUN,CUE2FTP,GROUP,DATEST,DATEND,rundir,HPSSTAR,gdas_prepbufr_arch,batch,runhpss,APRUN,COMROTNCO
#export listvar=$listvar1,$listvar2
${vsdbhome}/grid2obs/grid2obs.sh


### --------------------------------------------------------------
      fi                                       
### --------------------------------------------------------------

exit

