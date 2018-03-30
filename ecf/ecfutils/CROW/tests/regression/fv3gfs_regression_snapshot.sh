#!/bin/bash

usage () {
   echo -e "\033[1mUSAGE:\033[0m\n $0 [[baseline]] [[compare]] [[--non-interactive]]\n"
   echo -e "\tno arguments           : creates a baseline with sorc and exp dir in \$PWD named fvgfs_sorc_baseline fv3gfs_exp_basline respectivly"
   echo -e "\tone argument  (string) : creates a baseline with sorc and exp dir in \$PWD named fvgfs_sorc_\${string} fv3gfs_exp_\${string} respectivly\n\n"
   echo -e "\tone argument  (dir)       : creates a test run with sorc and exp dir in \$PWD named fvgfs_sorc_test_run   fv3gfs_exp_test_run respectivly \n\t\t\t\t    and then compares the results against the comrot found in the directory \${dir}"
   echo -e "\ttwo arguments (dir) (str) : creates a test_run with sorc and exp dir in \$PWD named fvgfs_sorc_\${string} fv3gfs_exp_\${srting} respectivly \n\t\t\t\t    and then compares the results against the comrot found in the directory \${dir} "
   echo -e "\ttwo arguments (dir) (dir) : does a bitwise compare on the gfs files from the first dir to the second\n"
   echo -e "\tthird optional argument is used when acctually running the script so no promps are given, otherwize the script will report on the settings.\n\n"
   echo -e "\033[1mEXAMPLE:\033[0m\n"
   echo -e "\tnohup ./fv3gfs_regression.sh baseline --non-interactive > & fv3gfs_regression_baseline_run.log &\n"
   exit
}

INTERACTIVE='TRUE'
for arg
 do
  if [[ $arg == "--non-interactive" ]]; then
   INTERACTIVE='FALSE'
   break
  fi
done

# Traps that only allow the above inputs specified in the usage

if [[ "$#" -gt "4" ]] || [[ $1 == '--help' ]]; then
 usage
fi

if [[ "$#" -ge "3" ]]; then  
 if [[ ! -d $1 ]]; then
  usage
 fi
fi

if [[ -f $1 ]] || [[ -f $2 ]]; then
 usage
fi

log_message () {
 logtime=`date +"%F %T"`
 echo -e "$1 : bash : $logtime : LOG : $2"
 if [[ $1 == "CRITICAL" ]]; then
  exit -1
 fi
}

CHECKOUT_DIR=$PWD
ROCOTO_WAIT_FRQUANCY='5m'

CHECKOUT=${CHECKOUT:-'TRUE'}
CREATE_EXP=${CREATE_EXP:-'TRUE'}
BUILD=${BUILD:-'TRUE'}
CREATE_EXP=${CREATE_EXP:-'TRUE'}
RUNROCOTO=${RUNROCOTO:-'TRUE'}
JOB_LEVEL_CHECK=${JOB_LEVEL_CHECK:-'FALSE'}
RZDM_RESULTS=${RZDM_RESULTS:-'FALSE'}
PYTHON_FILE_COMPARE=${PYTHON_FILE_COMPARE:-'TRUE'}

CHECKOUT='FALSE'
CREATE_EXP='FALSE'
BUILD='FALSE'
#RUNROCOTO='FALSE'
#JOB_LEVEL_CHECK='TRUE'
#RZDM_RESULTS='TRUE'
#PYTHON_FILE_COMPARE='FALSE'

idate='2017073118'
edate='2017080100'

fv3gfs_git_branch='master'
# Leave fv3gfs_svn_url blank to use git branch in fv3gfs_git_branch
fv3gfs_svn_url=''
load_rocoto='rocoto/1.2.4'

ICS_dir_cray='/gpfs/hps3/emc/global/noscrub/emc.glopara/ICS'
PTMP_cray='/gpfs/hps3/ptmp'
ICS_dir_theia='/scratch4/NCEPDEV/global/noscrub/glopara/ICS/FV3GFS'
PTMP_theia='/scratch4/NCEPDEV/stmp4'

# If RZDM is set then the viewer will attempt to post the state of the workflow in html on the rzdm server
RZDM='tmcguinness@emcrzdm.ncep.noaa.gov:/home/www/emc/htdocs/gc_wmb/tmcguinness'
ROCOTOVIEWER='/u/Terry.McGuinness/bin/rocoto_viewer.py'

find_data_dir () {

    local _check_baseline_dir=$1

    STARTTIME=$(date +%s)
    while IFS= read -r -d '' file
    do
       gfsfile=`basename $file | cut -f 1 -d"."`
       if [[ $gfsfile == "enkf" ]]; then
          check_real_base_dir=`dirname $file`
          if ls $check_real_base_dir/gdas.* 1> /dev/null 2>&1; then
           real_base_dir=$check_real_base_dir
           break 
          fi
       fi
       if [[ $(($ENDTIME - $STARTTIME)) > 65 ]]; then
         log_message "CRITICAL" "looking for valid baseline directory put then gave up after a minute"
         exit -1
       fi
    ENDTIME=$(date +%s)
    done < <(find $_check_baseline_dir -print0 )

    if [[ -z $real_base_dir ]]; then
      exit -1
    fi
    _check_baseline_dir=`dirname $file`
    echo $_check_baseline_dir
}

COMPARE_BASE='FALSE'
if [[ ! -d $1 ]] && [[ ! -f $1 ]]; then
 if [[ -z $1 || $1 == "--non-interactive" ]]; then
    regressionID='baseline'
    log_message "INFO" "No arguments given assuming to make new baseline with default ID: $regressionID"
 else 
    regressionID=$1
    log_message "INFO" "only the baseline will be created with ID: $regressionID"
 fi
fi

log_message "INFO" "running regression script on host $HOST"

COMPARE_BASE='FALSE'
JUST_COMPARE_TWO_DIRS='FALSE'
if [[ -d $1 ]] && [[ -d $2 ]]; then
 CHECKOUT='FALSE'
 BUILD='FALSE'
 CREATE_EXP='FALSE'
 RUNROCOTO='FALSE'
 check_baseline_dir=`readlink -f $1`
 check_baseline_dir_get=$( find_data_dir $check_baseline_dir )
 if [[ -z $check_baseline_dir_get ]]; then
   log_message "CRITICAL" "$check_baseline_dir_get is not a directory with a baseline to test in it"
 fi
 if [[ $check_baseline_dir != $check_baseline_dir_get ]]; then
   check_baseline_dir=$check_baseline_dir_get
   log_message "WARNING" "given directory did not have gfs data, but a subsequent subdirectory was found that did:\n$check_baseline_dir"
 fi  
 check_baseline_dir_with_this_dir=`readlink -f $2`
 check_baseline_dir_with_this_dir_get=$( find_data_dir $check_baseline_dir_with_this_dir )
 if [[ -z $check_baseline_dir_with_this_dir_get ]]; then
   log_message "CRITICAL" "$check_baseline_dir_with_this_get is not a directory with a baseline to test in it"
 fi
 if [[ $check_baseline_dir_with_this_dir_get != $check_baseline_dir_with_this_dir ]]; then
   check_baseline_dir_with_this_dir=$check_baseline_dir_with_this_get
   log_message "WARNING" "given directory did not have gfs data, but a subsequent subdirectory was found that did:\n$check_baseline_dir_with_this_dir"
 fi  
 log_message "INFO" "simply doing a diff on these two directories:\n  $check_baseline_dir \n  $check_baseline_dir_with_this_dir"
 JUST_COMPARE_TWO_DIRS='TRUE'
 COMPARE_BASE='TRUE'
 if [[ -z $3 ]]; then
   regressionID='compare'
 else
   if [[ $3 != "--non-interactive" ]]; then
     regressionID=$3
   else
     regressionID='compare'
   fi
 fi
elif [[ -d $1 && ! -d $2 ]]; then
  check_baseline_dir=`readlink -f $1`
  if [[ -z $2 ]]; then
   regressionID='test_run'
  else
   if [[ $2 == "--non-interactive" ]]; then
     regressionID='test_run'
   else
     if [[ `echo $2  | cut -c1-2` == "--" ]]; then
       log_message "CRITICAL" "an errounous option was given ($2), --non-interactive is the only allowable option"
     else
       regressionID=$2
     fi
   fi
  fi
  log_message "INFO" "running test run ($regressionID) agaist regression baseline in directory $check_baseline_dir"
  COMPARE_BASE='TRUE'
  check_baseline_dir_get=$( find_data_dir $check_baseline_dir )
  if [[ -z $check_baseline_dir_get ]]; then
   log_message "CRITICAL" "$check_baseline_dir_get is not a directory with a baseline to test in it"
  fi
  if [[ $check_baseline_dir != $check_baseline_dir_get ]]; then
    check_baseline_dir=$check_baseline_dir_get
    log_message "WARNING" "given directory did not have gfs data, but a subsequent subdirectory was found that did:\n$check_baseline_dir"
  fi
 log_message "INFO" "found baseline fv3gfs gfs data found in directory: $check_baseline_dir"
fi

if [[ -d /scratch4/NCEPDEV ]]; then
  system="theia"
elif [[ -d /gpfs/hps3 ]]; then
  system="cray"
else
  log_message "CRITICAL" "Unknown machine $system, not supported"
fi

if [[ -z $ROCOTOVIEWER ]]; then
  RZDM_RESULTS="FALSE"
fi

echo -e "Current Settings are:\n"
echo "regressionID = $regressionID"
echo "git branch   = $fv3gfs_git_branch"
echo "idate        = $idate"
echo "edate        = $edate"
echo "CHECKOUT_DIR = $CHECKOUT_DIR"
echo "CHECKOUT     = $CHECKOUT"
echo "CREATE_EXP   = $CREATE_EXP"
echo "COMPARE_BASE = $COMPARE_BASE"
echo "RZDM_RESULTS = $RZDM_RESULTS"
echo -e "RUNROCOTO    = $RUNROCOTO\n"
echo "PYTHON_FILE_COMPARE = $PYTHON_FILE_COMPARE"
echo -e "JOB_LEVEL_CHECK = $JOB_LEVEL_CHECK\n"

if [[ $INTERACTIVE == "TRUE" ]]; then
   while read -n1 -r -p "Are these the correct settings (y/n): " answer
    do
    if [[ $answer == "n" ]]; then
     echo -e "\n"
     exit
    fi 
    if [[ $answer == "y" ]]; then
     echo -e "\n"
     break 
    fi
    echo ""
   done
fi

SCRIPT_STARTTIME=$(date +%s)

module load $load_rocoto
rocotoruncmd=`which rocotorun`
if [[ -z ${rocotoruncmd} ]]; then
  log_message "CRITICAL" "module load for rocoto ($load_rocoto) on system failed"
fi

# system dependent
#----------------- 

if [[ $system != "cray" ]] && [[ $system != 'theia' ]]; then
 log_message "CRITICAL" "system setting: $system is not set correctly (only options are cray or theia)"
fi

if [[ $system == "cray" ]]; then
 ICS_dir=$ICS_dir_cray
 PTMP=$PTMP_cray
else
 ICS_dir=$ICS_dir_theia
 PTMP=$PTMP_theia
fi

rocotover=`$rocotoruncmd --version`
log_message "INFO" "using rocoto version $rocotover"
rocotostatcmd=`which rocotostat`

fv3gfs_ver='v15.0.0'
num_expected_exec='29'

pslot_basename='fv3gfs'
checkout_dir_basename="${pslot_basename}_sorc_${regressionID}"
pslot="${pslot_basename}_exp_${regressionID}"

ROCOTO_XML="${pslot}_joblevel.xml"
ROCOTO_DB="${pslot}_joblevel.db"
COMP_ROTDIRS_PYTHON="/gpfs/hps3/emc/global/noscrub/Terry.McGuinness/REGRESSION_TESTS/compare_folders.py"

username=`echo ${USER} | tr '[:upper:]' '[:lower:]'`
#setup_expt=${CHECKOUT_DIR}/${checkout_dir_basename}/gfs_workflow.${fv3gfs_ver}/ush/setup_expt.py
setup_expt=/gpfs/hps3/emc/global/noscrub/emc.glopara/CROW/snapshot_20180113/master_20180113/gfs_workflow.v15.0.0/ush/setup_expt.py
#setup_workflow=${CHECKOUT_DIR}/${checkout_dir_basename}/gfs_workflow.${fv3gfs_ver}/ush/setup_workflow.py
setup_workflow=/gpfs/hps3/emc/global/noscrub/emc.glopara/CROW/snapshot_20180113/master_20180113/gfs_workflow.v15.0.0/ush/setup_workflow.py
#config_dir=${CHECKOUT_DIR}/${checkout_dir_basename}/gfs_workflow.${fv3gfs_ver}/config
config_dir=/gpfs/hps3/emc/global/noscrub/emc.glopara/CROW/snapshot_20180113/master_20180113/gfs_workflow.v15.0.0/config


if [[ $CHECKOUT == 'TRUE' ]]; then
  cd ${CHECKOUT_DIR}
  if [[ ! -z ${fv3gfs_svn_url} ]]; then

    if [[ -d ${checkout_dir_basename} ]]; then
       rm -Rf ${checkout_dir_basename}
    fi
    log_message "INFO" "checking out fv3gfs from svn $fv3gfs_svn_url"
    svn co $fv3gfs_svn_url ${checkout_dir_basename}

  else

   log_message "INFO" "cloning fvgfs from git with branch $fv3gfs_git_branch"
   log_message "INFO" "git clone ssh://${username}@vlab.ncep.noaa.gov:29418/fv3gfs ${checkout_dir_basename}"
   git clone ssh://${username}@vlab.ncep.noaa.gov:29418/fv3gfs ${checkout_dir_basename}

   if [[ ! -z "${fv3gfs_git_branch}// }" ]]; then
    cd ${checkout_dir_basename}
    git checkout remotes/origin/${fv3gfs_git_branch} -b ${fv3gfs_git_branch}
    git rev-parse HEAD | xargs git show --stat
    cd ${CHECKOUT_DIR}
   fi

  fi
fi

comrot=${CHECKOUT_DIR}/fv3gfs_regression_experments
comrot_test_dir=${comrot}/${pslot}
exp_dir_fullpath=${CHECKOUT_DIR}/${pslot}
#exp_setup_string="--pslot ${pslot} --icsdir $ICS_dir --configdir ${config_dir} --comrot ${comrot} --idate $idate --edate $edate --expdir ${CHECKOUT_DIR}"
exp_setup_string="--pslot ${pslot} --icsdir $ICS_dir --configdir ${config_dir} --comrot ${comrot} --idate $idate --edate $edate --expdir ${CHECKOUT_DIR} --resdet 96 --resens 96 --nens 20 --gfs_cyc 4"

if [[ $CREATE_EXP == 'TRUE' ]]; then

    log_message "INFO" "setting up experiment: ${setup_expt} ${exp_setup_string}"
    removed=''
    if [[ -d $exp_dir_fullpath ]]; then
     removed='it was present but now has been removed'
    fi
    rm -Rf $exp_dir_fullpath
    log_message "INFO" "experiment directory is $exp_dir_fullpath $removed"
    removed=''
    if [[ -d $comrot_test_dir ]]; then
     removed='it was present but now has been removed'
    fi
    rm -Rf $comrot_test_dir
    log_message "INFO" "comrot directory is $comrot_test_dir $removed"

    yes | ${setup_expt} ${exp_setup_string}
    log_message "INFO" "setting up workflow: ${setup_workflow} --expdir $exp_dir_fullpath"
    yes | ${setup_workflow} --expdir $exp_dir_fullpath
    sed -i 's/^export VRFYGENESIS=.*/export VRFYGENESIS=\"NO\"          \# WARNING changed by regression script/' $exp_dir_fullpath/config.vrfy
    log_message "WARNING" "modified config.vrfy with VRFYGENESIS=NO because geneses tracker is currently failing"
    sed -i 's/^export VRFYG2OBS=.*/export VRFYG2OBS=\"NO\"          \# WARNING changed by regression script/' $exp_dir_fullpath/config.vrfy
    log_message "WARNING" "modified config.vrfy with VRFYG2OBS=NO because it do not make sense for it to be on for only one cycle"
fi

if [[ $BUILD == 'TRUE' ]]; then
 cd ${checkout_dir_basename}/global_shared.${fv3gfs_ver}/sorc

   log_message "INFO" "running checkout script: $PWD/checkout.sh $username"
  ./checkout.sh $username
   log_message "INFO" "running build script: $PWD/build_all.sh $system"
  ./build_all.sh ${system}
  num_shared_exec=`ls -1 ../exec | wc -l`
 if [[ $num_shared_exec != $num_expected_exec ]]; then
   log_message "WARNING" "number of executables in shared exec: $num_shared_exec was found and was expecting $num_expected_exec"
   filepath='../exe'
   fullpath=`echo $(cd $(dirname $filepath ) ; pwd ) /$(basename $filepath )`
   log_message "WARNING" "check the executables found in: $fullpath"
 else
   log_message "INFO" "number of executables in shared exec: $num_shared_exec"
 fi
fi

run_file_compare_python () {

   total_number_files=`find $check_baseline_dir -type f | wc -l`
   if [[ $JUST_COMPARE_TWO_DIRS == 'TRUE' ]]; then
    comrot_test_dir=$check_baseline_dir_with_this_dir
   fi
   log_message "INFO" "doing the diff compare in $check_baseline_dir against $comrot_test_dir"
   if [[ ! -d $check_baseline_dir ]] || [[ ! -d $comrot_test_dir ]]; then
     log_message "CRITICAL" "one of the target directories does not exist"
   fi

   log_message "INFO" "running: compare_folders.py $check_baseline_dir $comrot_test_dir -n $regressionID"
   $COMP_ROTDIRS_PYTHON --cmp_dirs $check_baseline_dir $comrot_test_dir -n $regressionID

}

run_file_compare () {

    log_message "INFO" "doing job level comparing with job $regressionID" 
    if [[ $COMPARE_BASE == 'TRUE' ]]; then
       PWD_start=$PWD
       diff_file_name="${CHECKOUT_DIR}/diff_file_list_${regressionID}.lst"
       total_number_files=`find $check_baseline_dir -type f | wc -l`
       if [[ $system == "theia" ]]; then
        module load nccmp
        NCCMP=`which nccmp`
       else
        NCCMP=/gpfs/hps3/emc/nems/noscrub/emc.nemspara/FV3GFS_V0_RELEASE/util/nccmp
       fi

       if [[ $JUST_COMPARE_TWO_DIRS == 'TRUE' ]]; then
        comrot_test_dir=$check_baseline_dir_with_this_dir
       fi
       log_message "INFO" "doing the diff compare in $check_baseline_dir against $comrot_test_dir"
       if [[ ! -d $check_baseline_dir ]] || [[ ! -d $comrot_test_dir ]]; then
         log_message "CRITICAL" "one of the target directories does not exist"
       fi
       log_message "INFO" "moving to directory $comrot_test_dir to do the compare"
       if [[ -d $comrot_test_dir ]]; then
         cd $comrot_test_dir/..
       else
         log_message "CRITICAL" "The directory $comrot_test_dir does not exsist"
       fi
       check_baseline_dir_basename=`basename $check_baseline_dir`
       comrot_test_dir_basename=`basename $comrot_test_dir`

       log_message "INFO" "running command: diff --brief -Nr --exclude \"*.log*\" --exclude \"*.nc\" --exclude \"*.nc?\"  $check_baseline_dir_basename $comrot_test_dir_basename >& $diff_file_name" 
       diff --brief -Nr --exclude "*.log*" --exclude "*.nc" --exclude "*.nc?" $check_baseline_dir_basename $comrot_test_dir_basename >> ${diff_file_name} 2>&1

       num_different_files=`wc -l < $diff_file_name`
       log_message "INFO" "checking of the $num_different_files differing files (not including NetCDF) for which ones are tar and/or compressed files for differences"
       rm -f ${diff_file_name}_diff
       counter_diffed=0
       counter_regularfiles=0
       counter_compressed=0
       while read line; do
        set -- $line;
        file1=$2;
        file2=$4;

           if ( tar --exclude '*' -ztf $file1 ) ; then
            #log_message "INFO" "$file1 is an compressed tar file"
            counter_compressed=$((counter_compressed+1))
            if [[ $( tar -xzf $file1 -O | md5sum ) != $( tar -xzf $file2 -O | md5sum ) ]] ; then
               #log_message "INFO" "found $file1 and $file2 gzipped tar files DO differ" 
               counter_diffed=$((counter_diffed+1))
               echo "compressed tar $line" >> ${diff_file_name}_diff
            fi
           elif ( tar --exclude '*' -tf  $file1 ) ; then
             counter_compressed=$((counter_compressed+1))
             #log_message "INFO" "$file1 is an uncompressed tar file"
             if [[ $( tar -xf $file1 -O | md5sum ) != $( tar -xf $file2 -O | md5sum ) ]] ; then
               #log_message "INFO" "found $file1 and $file2 tar files DO differ" 
               counter_diffed=$((counter_diffed+1))
               echo "tar $line" >> ${diff_file_name}_diff
             fi
           else
             #log_message "INFO" "$file1 is not tar or tar.gz and still then differs" 
             counter_regularfiles=$((counter_regularfiles+1))
             echo $line >> ${diff_file_name}_diff
           fi

       done < $diff_file_name

       log_message "INFO" "out of $num_different_files differing files $counter_compressed where tar or compressed and $counter_diffed of those differed"

       if [[ -f ${diff_file_name}_diff ]]; then
        mv  ${diff_file_name}_diff ${diff_file_name}
       fi

       log_message "INFO" "checking if test case has correct number of files"

       baseline_tempfile=${check_baseline_dir_basename}_files.txt
       comrot_tempfile=${comrot_test_dir_basename}_files.txt
       cd $check_baseline_dir_basename
       rm -f ../$baseline_tempfile
       find * -type f > ../$baseline_tempfile
       cd ../$comrot_test_dir_basename
       rm -f ../$comrot_tempfile
       find * -type f > ../$comrot_tempfile
       cd ..
       diff ${baseline_tempfile} ${comrot_tempfile} > /dev/null 2>&1
       if [[ $? != 0 ]]; then
         num_missing_files=0
         while read line; do
          ls ${comrot_test_dir_basename}/$line > /dev/null 2>&1
          if [[ $? != 0 ]]; then
            echo "file $line is in ${check_baseline_dir_basename} but is missing in ${comrot_test_dir_basename}" >> ${diff_file_name}
            num_missing_files=$((num_missing_files+1))
          fi  
         done < $baseline_tempfile
         while read line; do
          ls ${check_baseline_dir_basename}/$line > /dev/null 2>&1
          if [[ $? != 0 ]]; then
            echo "file $line is in ${comrot_test_dir_basename} but is missing in $check_baseline_dir_basename" >> ${diff_file_name}
            num_missing_files=$((num_missing_files+1))
          fi  
         done < $comrot_tempfile
         if [[ $num_missing_files != 0 ]]; then
           log_message "INFO" "$num_missing_files files where either  missing or where unexpected in the test direcotry."
         else
           log_message "INFO" "all the files are accounted for are all the names match in the test directory"
         fi
       else
         log_message "INFO" "all the files are accounted for are all the names match in the test directory"
       fi
       rm -f $baseline_tempfile
       rm -f $comrot_tempfile

       log_message "INFO" "comparing NetCDF files ..."
       find $check_baseline_dir_basename -type f \( -name "*.nc?" -o -name "*.nc" \) > netcdf_filelist.txt
       num_cdf_files=`wc -l < netcdf_filelist.txt`
       counter_identical=0
       counter_differed_nccmp=0
       counter_header_identical=0
       while IFS=/ read netcdf_file; do
         comp_base=`basename $netcdf_file`
         dir_name=`dirname $netcdf_file`
         just_dir=`echo "$dir_name" | sed 's,^[^/]*/,,'`
         file1=$check_baseline_dir_basename/$just_dir/$comp_base ; file2=$comrot_test_dir_basename/$just_dir/$comp_base
         diff $file1 $file2 > /dev/null 2>&1
         if [[ $? != 0 ]]; then
             nccmp_result=$( { $NCCMP --diff-count=4 --threads=4 --data $file1 $file2; } 2>&1) 
             if [[ $? != 0 ]]; then
              counter_differed_nccmp=$((counter_differed_nccmp+1))
              echo "NetCDF file $file1 differs: $nccmp_result" >> $diff_file_name
             else 
              counter_header_identical=$((counter_header_identical+1))
             fi
         else
           counter_identical=$((counter_identical+1))
         fi
       done < netcdf_filelist.txt
       log_message "INFO" "out off $num_cdf_files NetCDF files $counter_identical where completely identical, $counter_header_identical identical data but differed in the header, and $counter_differed_nccmp differed in the data"
       number_diff=`wc -l < $diff_file_name`
       log_message "INFO" "completed running diff for fv3gfs regression test ($regressionID) and found results in file: $diff_file_name"
       log_message "INFO" "out of $total_number_files files, there where $number_diff that differed"
       rm netcdf_filelist.txt

       cd $PWD_start
    fi
}


regressionID_save=$regressionID
if [[ $RUNROCOTO == 'TRUE' ]]; then
    if [[ ! -d ${exp_dir_fullpath} ]]; then
     log_message "CRITICAL" "experiment directory $exp_dir_fullpath not found"
    fi
    log_message "INFO" "running regression script on host $HOST"
    log_message "INTO" "moving to PWD $exp_dir_fullpath to run cycleing in experiment directory"
    cd ${exp_dir_fullpath}

    log_message "INFO" "starting to run fv3gfs cycling regression test run using $rocotoruncmd -d $ROCOTO_DB -w $ROCOTO_XML"
    log_message "INFO" "running $rocotoruncmd from $PWD"

    $rocotoruncmd -d $ROCOTO_DB -w $ROCOTO_XML
    if [[ $? != 0 ]]; then
      log_message "CRITICAL" "rocotorun failed on first attempt"
    fi
    if [[ -d $ROCOTO_DB ]]; then
     log_message "CRITICAL" "rocotorun failed to create database file"
    fi
    log_message "INFO" "rocotorun successfully ran initial rocoorun to to create database file:  $ROCOTO_DB"

    log_message "INFO" "running: $rocotostatcmd -d $ROCOTO_DB -w $ROCOTO_XML -s -c all | tail -1 | awk '{print \$1}'"
    lastcycle=`$rocotostatcmd -d $ROCOTO_DB -w $ROCOTO_XML -s -c all | tail -1 | awk '{print $1}'`
    if [[ $? != 0 ]]; then
     log_message "CRITICAL" "rocotostat failed when determining last cycle in test run"
    fi
    log_message "INFO" "rocotostat determined that the last cycle in test is: $lastcycle"

    cycling_done="FALSE"
    last_succeeded_checked=""
    last_succeeded=""
    while [ $cycling_done == "FALSE" ]; do
      lastcycle_state=`$rocotostatcmd -d $ROCOTO_DB -w $ROCOTO_XML -c $lastcycle -s | tail -1 | awk '{print $2}'`
      if [[ $lastcycle_state == "Done" ]]; then
       log_message "INFO" "last cycle $lastcycle just reported to be DONE by rocotostat .. exiting execution of workflow"
       break
      fi
      #log_message "INFO" "running: $rocotostatcmd -d $ROCOTO_DB -w $ROCOTO_XML -c all"
      deadjobs=`$rocotostatcmd -d $ROCOTO_DB -w $ROCOTO_XML -c all | awk '$4 == "DEAD" {print $2}'`
      if [[ ! -z $deadjobs ]]; then
         deadjobs=`echo $deadjobs | tr '\n' ' '`
         log_message "CRITICAL" "the following jobs are DEAD: $deadjobs exiting script with error code (-1)"
         exit -1
      fi
      deadcycles=`$rocotostatcmd -d $ROCOTO_DB -w $ROCOTO_XML -c $lastcycle -s | awk '$2 == "Dead" {print $1}'`
      if [[ ! -z $deadcycles ]]; then
       log_message "CRITICAL" "the following cycles are dead: $deadcycles exiting script with error code (-2)"
       exit -2
      fi
      $rocotoruncmd -d $ROCOTO_DB -w $ROCOTO_XML
      if [[ $? == "0" ]]; then
       last_succeeded=`$rocotostatcmd -d $ROCOTO_DB -w $ROCOTO_XML -c all | awk '$4 == "SUCCEEDED" {print $1"_"$2}' | tail -1`
       log_message "INFO" "Successfully ran: $rocotoruncmd -d $ROCOTO_DB -w $ROCOTO_XML"
       #log_message "INFO" "using job level checking: last succeded task checked: $last_succeeded_checked"
       #log_message "INFO" "using job level checking: last succeded task current: $last_succeeded"
       if [[ ! -z $last_succeeded ]]; then
         if [[ $last_succeeded != $last_succeeded_checked ]]; then
               last_succeeded_checked=$last_succeeded
               regressionID=$last_succeeded
               log_message "INFO" "job $last_succeeded just completed successfully" 
               if [[ $JOB_LEVEL_CHECK == 'TRUE' ]]; then
                 if [[ $PYTHON_FILE_COMPARE == 'TRUE' ]]; then
                   log_message "WARNING" "python file compare set but does not support job level checking (reverting to bash shell version)"
                   run_file_compare
                 fi
               else
                run_file_compare_python
               fi
         fi
       fi
      else 
       log_message "WARNING" "FAILED: $rocotoruncmd -d $ROCOTO_DB -w $ROCOTO_XML"
      fi

      # Wait here to before running rocotorun again ...
      log_message "INFO" "Waiting here for $ROCOTO_WAIT_FRQUANCY ..."
      sleep $ROCOTO_WAIT_FRQUANCY 

      if [[ $RZDM_RESULTS == 'TRUE' ]]; then
          if [[ ! -z $RZDM ]]; then
            viewer_arg_str="-d $ROCOTO_DB -w $ROCOTO_XML --html=$RZDM"
            cd ${exp_dir_fullpath}
            $ROCOTOVIEWER $viewer_arg_str
            if [[ $? == "0" ]]; then 
              log_message "INFO" "state of workflow posted at $RZDM"
            else
              log_message "WARNING" "attempt to write stats to the rzdm server failed"
            fi
          fi
      fi

   done
   log_message "INFO" "rocotorun completed successfully"
fi

regressionID=$regressionID_save
if [[ $COMPARE_BASE == 'TRUE' ]]; then
  if [[ $PYTHON_FILE_COMPARE == 'TRUE' ]]; then
    run_file_compare_python
  else
    run_file_compare
  fi
fi  

DATE=`date`
if [[ $number_diff == 0 ]]; then
  log_message "INFO" "regression tests script completed successfully on $DATE with no file differences"
else
    if (( $number_diff > 500 )); then
      some="many"
    elif (( $number_diff < 100 )); then
      some="some"
    else
      some="several"
    fi
  log_message "INFO" "regression tests script completed successfully on $DATE with $some file differences"
fi
SCRIPT_ENDTIME=$(date +%s)
PROCESSTIME=$(($SCRIPT_ENDTIME-$SCRIPT_STARTTIME))
log_message "INFO" "total process time $PROCESSTIME seconds"
