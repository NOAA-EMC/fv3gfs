#! /bin/sh

# Theia workaround.  Reduce stack soft limit while running "module" to
# avoid runaway memory allocation:
ulimit_s=$( ulimit -S -s )
ulimit -S -s 10000

source /apps/lmod/lmod/init/sh

# FIXME: Remove hard-coded modules.
module purge
module use /scratch4/NCEPDEV/nems/noscrub/emc.nemspara/python/modulefiles/
module load python/3.6.1-emc
module load intel
module load impi

# Restore stack soft limit:
ulimit -S -s "$ulimit_s"
unset ulimit_s

set -xue

export PYTHONPATH="$HOMEcrow${PYTHONPATH:+:$PYTHONPATH}"

python3.6 -c 'import crow ; print(f"CROW library version {crow.version}")'

"$HOMEtest/jobs/$1"
