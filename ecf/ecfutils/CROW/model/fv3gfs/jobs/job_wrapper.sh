#! /bin/sh

# Theia workaround.  Reduce stack soft limit while running "module" to
# avoid runaway memory allocation:
ulimit_s=$( ulimit -S -s )
ulimit -S -s 10000

source "$BASE_MODULES"/module-setup.sh.inc
module use "$BASE_MODULES"
module load module_base.$( echo $MACHINE | tr A-Z a-z )

# FIXME: Remove hard-coded modules.
module use /scratch4/NCEPDEV/nems/noscrub/emc.nemspara/python/modulefiles/
module unload python anaconda
module load python/3.6.1-emc

# Restore stack soft limit:
ulimit -S -s "$ulimit_s"
unset ulimit_s

module list

set -xue

export PYTHONPATH="$HOMEcrow${PYTHONPATH:+:$PYTHONPATH}"

python3.6 -c 'import crow ; print(f"CROW library version {crow.version}")'

if [[ "${1:0:1}" == "/" ]] ; then
    exec "$@"
fi

# Relative path is from j-jobs directory
prog=$1
shift
exec "$BASE_JOB/$prog.sh" "$@"
