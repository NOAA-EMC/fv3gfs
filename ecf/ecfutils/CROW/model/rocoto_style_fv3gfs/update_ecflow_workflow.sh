#! /bin/bash

set -ue

# Get the directory in which this script resides.  We'll assume the
# yaml files are there:
dir0=$( dirname "$0" )
here=$( cd "$dir0" ; pwd -P )

export WORKTOOLS_VERBOSE=NO

# Make sure this directory is in the python path so we find worktools.py:
export PYTHONPATH=$here:${PYTHONPATH:+:$PYTHONPATH}

# Parse arguments:
if [[ "$1" == "-v" ]] ; then
    export WORKTOOLS_VERBOSE=YES
    shift 1
fi
export EXPDIR="$1"
export FIRST_CYCLE="$2"
export LAST_CYCLE="$3"

if [[ ! -d /usrx/local || -e /etc/redhat-release ]] ; then
   echo "ERROR: This script only runs on WCOSS Cray" 1>&2
   exit 1
fi

if ( ! which ecflow_client > /dev/null 2>&1 ) ; then
    echo "ERROR: There is no ecflow_client in your \$PATH.  Load the ecflow module."
    exit 1
fi

if [[ "${ECF_ROOT:-Q}" == Q ]] ; then
    echo "ERROR: You need to set \$ECF_ROOT"
    exit 1
fi

if [[ "${ECF_HOME:-Q}" == Q ]] ; then
    echo "ERROR: You need to set \$ECF_HOME.  I suggest \$ECF_ROOT/submit"
    exit 1
fi

if [[ "${ECF_PORT:-Q}" == Q ]] ; then
    echo "ERROR: You need to set \$ECF_PORT.  See /usrx/local/sys/ecflow/assigned_ports.txt"
    exit 1
fi

export ECF_HOME="${ECF_HOME:-$ECF_ROOT/submit}"

if [[ "${WORKTOOLS_VERBOSE:-NO}" == YES ]] ; then 
    echo "begin_ecflow_workflow.sh: verbose mode"
    export redirect=" "
else
    export redirect="> /dev/null 2>&1"
fi

echo "ecFlow server port: $ECF_PORT"
echo "ecFlow server root: $ECF_ROOT"
echo "ecFlow server home: $ECF_HOME"

set +e
if ( ! which python3 > /dev/null 2>&1 || \
     ! python3 -c 'import yaml ; f{"1+1"}' > /dev/null 2>&1 ) ; then
    python36=/gpfs/hps3/emc/nems/noscrub/Samuel.Trahan/python/3.6.1-emc/bin/python3.6
else
    python36="$( which python3 )"
fi
set -e

if [[ "${WORKTOOLS_VERBOSE:-NO}" == YES ]] ; then
    set -x
fi

/ecf/devutils/server_check.sh "$ECF_ROOT" "$ECF_PORT" $redirect || true

if ( ! ecflow_client --ping $redirect ) ; then
    echo "Could not connect to ecflow server.  Aborting."
    exit 1
fi

$python36 -c "
import worktools ;
worktools.add_cycles_to_running_ecflow_workflow_at(
  '$EXPDIR',
  '$FIRST_CYCLE',
  '$LAST_CYCLE'
)"






