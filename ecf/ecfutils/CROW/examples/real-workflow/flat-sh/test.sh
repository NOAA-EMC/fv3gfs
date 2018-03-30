#! /bin/sh

set -xue

seed=381
nx=400
ny=400
ens_members=20
start_time=0
cycle_len=6
fcst_len=24
dt_write_fcst=3

dt_rand_fcst=500
dt_rand_ens_fcst=100

rm -rf com
mkdir com

exec=../exec/mpi
run="mpirun -np 48"
export KMP_AFFINITY=scatter
export KMP_NUM_THREADS=4
export MKL_NUM_THREADS=1

########################################################################

# Climatology initialization before first cycle

cat<<EOF > climatology_init.nl
&settings
  nx=$nx
  ny=$ny
  global_seed=$seed
  outfile="clim-init.grid"
/
EOF

$run $exec/climatology_init

# ----------------------------------------------------------------------

# Climatology forecast

cat<<EOF > forecast.nl
&settings
  nx=$nx
  ny=$ny
  infile="clim-init.grid"
  outfile_format="output_######.grid"
  dt_write=$cycle_len
  start_time=0
  end_time=$cycle_len
  global_seed=$seed
  dt_rand=$dt_rand_fcst
/
EOF
$run $exec/forecast
outfile=$( printf output_%06d.grid $cycle_len )
if [[ ! -s $outfile ]] ; then
    echo climatology: $outfile missing 1>&2
    exit 1
fi
mv $outfile clim-fcst.grid
rm -f output*grid

prior_analysis=clim-init.grid
prior_forecast=clim-fcst.grid
cycle_start_time=0

########################################################################

# Forecast cycling loop

for cycle in 2017100318 2017100400 2017100406 ; do
    cycle_start_time=$(( cycle_start_time + cycle_len ))
    cycle_end_time=$(( cycle_start_time + fcst_len ))

    rm -rf com/$cycle/
    mkdir -p com/$cycle/

    test -s $prior_forecast
    test -s $prior_analysis

    # ----------------------------------------------------------------

    # Ensemble and control

    for member in $( seq 0 $ens_members ) ; do
        cat<<EOF > forecast.nl
&settings
  nx=$nx
  ny=$ny
  infile="$prior_analysis"
  outfile_format="output_######.grid"
  dt_write=$cycle_len
  start_time=$cycle_start_time
  end_time=$(( cycle_start_time + cycle_len ))
  global_seed=$(( seed + member ))
  dt_rand=$dt_rand_ens_fcst
/
EOF
        $run $exec/forecast
        outfile=$( printf output_%06d.grid $cycle_len )
        if [[ ! -s $outfile ]] ; then
            echo $member: $outfile missing 1>&2
            exit 1
        fi
        mv $outfile $( printf member_%06d.grid $member )
        rm -f output*grid
    done
    rm -f forecast.nl

    # -----------------------------------------------------------------

    # Data assimilation

    cat<<EOF > assimilate.nl
&settings
  nx=$nx
  ny=$ny
  members=$ens_members
  analysis_out="analysis.grid"
  ensemble_format="member_######.grid"
  guess_in="$prior_forecast"
/
EOF
    $run $exec/assimilate

    cp -fp analysis.grid com/$cycle/analysis.grid

    # ----------------------------------------------------------------

    # Forecast

    cat<<EOF > forecast.nl
&settings
  nx=$nx
  ny=$ny
  infile="analysis.grid"
  outfile_format="fcst_######.grid"
  dt_write=$dt_write_fcst
  start_time=$cycle_start_time
  end_time=$cycle_end_time
  global_seed=$seed
  dt_rand=$dt_rand_fcst
/
EOF

    $run $exec/forecast

    cp -fp fcst_*.grid com/$cycle/.

    # ----------------------------------------------------------------

    # Post

    for infile in fcst_*.grid ; do
        postfile=$( echo $infile | sed s,fcst_,post_,g | sed s,grid,txt,g )
        cat<<EOF > post.nl
&settings
  nx=$nx
  ny=$ny
  infile="$infile"
/
EOF
        $run $exec/post > com/$cycle/$postfile
    done

    # ----------------------------------------------------------------

    # Finalize cycle, prepare for next cycle

    prior_analysis=com/$cycle/analysis.grid
    prior_forecast=$( printf com/$cycle/fcst_%06d.grid $cycle_len )

    echo Cycle $cycle complete.
done
