#! /bin/sh
#BSUB -q %QUEUE%
#BSUB -P GFS-T2O
#BSUB -J my_array.num_n1
#BSUB -o my_array.num_n1
#BSUB -W 0:02
#BSUB -R rusage[mem=5]
#BSUB -extsched CRAYLINUX[]
export NODES=2
%include <head.h>
echo ${JOBgfs}/JGFS_NUM_N1

%include <tail.h>
