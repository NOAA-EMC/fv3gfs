#! /bin/sh

export PYTHONPATH=../../${PYTHONPATH:+:$PYTHONPATH}

set -eu

rm -f test-??

./shell_prep.py

crow_deliver() {
    flow="$1"
    format="$2"
    cycle="$3"
    actor="$4"
    shift 4
    ../../crow_dataflow_deliver_sh.py -v "$flow" "$format" test.db "$cycle" "$actor" "$@"
}

echo ======================================== output
../../crow_dataflow_find_sh.py -v test.db O
echo
echo ======================================== input
../../crow_dataflow_find_sh.py -v test.db I
echo
echo ======================================== add cycles
for cyc in 2017-08-15t00:00:00 2017-08-15t06:00:00 2017-08-15t12:00:00 ; do
    echo ============================== "$cyc"
    ../../crow_dataflow_cycle_sh.py -v test.db add "$cyc"
done
echo ======================================== del first cycle
../../crow_dataflow_cycle_sh.py -v test.db del 2017-08-15t00:00:00
echo ======================================== check for second cycle input
cycle=2017-08-15t06:00:00
echo stdin for fam.job1 oslot | \
../../crow_dataflow_deliver_sh.py -c -o - test.db $cycle \
  fam.job2 slot=tslot

../../crow_dataflow_deliver_sh.py -c -m -o - \
    test.db $cycle fam.job3 slot=islot

echo ======================================== deliver first cycle output
cycle=2017-08-15t06:00:00
echo stdin for fam.job1 oslot | \
../../crow_dataflow_deliver_sh.py -i - test.db $cycle \
    fam.job1 slot=oslot

../../crow_dataflow_find_sh.py test.db O actor=fam.job2 | \
while [[ 1 == 1 ]] ; do
    set +e
    read flow actor slot meta > /dev/null
    if  [[ "$?" != 0 ]] ; then
        break
    fi
    echo $flow $actor $slot $meta
    set -e
    echo "testfile for $flow $actor $slot $meta $cycle" > testfile
    ../../crow_dataflow_deliver_sh.py -i testfile test.db $cycle \
        "$actor" "slot=$slot" ${meta:- }
done

echo ======================================== obtain second cycle input
cycle=2017-08-15t12:00:00

../../crow_dataflow_deliver_sh.py -o - test.db $cycle \
  fam.job2 slot=tslot

../../crow_dataflow_deliver_sh.py -m -o 'test-{plopnum}{letter}' \
    test.db $cycle fam.job3 slot=islot

for PL in 1A 1B 2A 2B 3A 3B ; do
    echo fam.job3 islot $PL text $( head -1 test-$PL )
done
echo ======================================== check for second cycle input

../../crow_dataflow_deliver_sh.py -c -o - test.db $cycle \
  fam.job2 slot=tslot

../../crow_dataflow_deliver_sh.py -c -m -o - \
    test.db $cycle fam.job3 slot=islot

