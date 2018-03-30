BThis is an actual workflow driven by CROW.

Steps to run:

you@theia> cd sorc
you@thiea> make theia-impi
you@theia> cd ../workflow
you@theia> module use /scratch4/NCEPDEV/nems/noscrub/emc.nemspara/python/modulefiles/                                                                                   
you@theia> module load python/3.6.1-emc
you@theia> /usr/bin/env PYTHONPATH=../../.. ./setup_expt.py
setup_expt:18:     INFO: Remove platforms from configuration.
setup_expt:24:     INFO: Run directory: /scratch4/NCEPDEV/stmp3/Samuel.Trahan/expt
setup_expt:42:     INFO: Write econfig file: /scratch4/NCEPDEV/stmp3/Samuel.Trahan/expt/config.yaml
setup_expt:49:     INFO: Experiment name: expt
setup_expt:53:     INFO: Rocoto XML file: /scratch4/NCEPDEV/stmp3/Samuel.Trahan/expt/expt.xml
setup_expt:56:     INFO: Workflow XML file is generated.
setup_expt:57:     INFO: Use Rocoto to execute this workflow.

Notice this path:

Rocoto XML file: /scratch4/NCEPDEV/stmp3/Samuel.Trahan/expt/expt.xml

You need to run the Rocoto workflow that resides in that directory.

you@theia> cd /scratch4/NCEPDEV/stmp3/Samuel.Trahan/expt/
you@theia> module load rocoto
you@theia> rocotorun -w expt.xml -d expt.db --verbose 10 # repeat until complete (or bored)


