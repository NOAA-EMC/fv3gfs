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
export CONFIGDIR="$1"
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
    echo "remake_ecflow_files_for.sh: verbose mode"
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

tmpfile=${TMPDIR:-/tmp}/find-expdir.$RANDOM.$RANDOM.$$

make_yaml_files() {
    # NOTE: Sourcing config.base clobbers the ecflow variables, so we
    # must do it in a subshell.
    set +uex
    source "$CONFIGDIR"/config.base $redirect
    set -ue
    
    if [[ "$FHMAX_GFS" != 240 ]] ; then
        echo "ERROR: This script requires FHMAX_GFS = 240" 1>&2
	exit 1
    fi

    if [[ "${WORKTOOLS_VERBOSE:-NO}" == YES ]] ; then
	set -x
    fi

    $python36 -c "import worktools ; worktools.make_yaml_files('$here','$EXPDIR')"

    echo "$EXPDIR" > "$tmpfile"
}

if ( ! ( make_yaml_files ) ) ; then
    echo "Failed to make YAML files"
    exit 1
fi

EXPDIR=$( cat "$tmpfile" )
rm -f "$tmpfile"

if [[ "${WORKTOOLS_VERBOSE:-NO}" == YES ]] ; then
    echo "remake_ecflow_files_for.sh: EXPDIR=$EXPDIR"
    set -x
fi

/ecf/devutils/server_check.sh "$ECF_ROOT" "$ECF_PORT" $redirect || true

if ( ! ecflow_client --ping $redirect ) ; then
    echo "Could not connect to ecflow server.  Aborting."
    exit 1
fi

$python36 -c "import worktools ; worktools.remake_ecflow_files_for_cycles(
  '$EXPDIR',
  '$FIRST_CYCLE',
  '$LAST_CYCLE')"






