#! /bin/sh

set -ue

PYTHONPATH=$( pwd )/../../${PYTHONPATH:+${PYTHONPATH}:}
TO_SH=../../to_sh.py

test -s $TO_SH
test -x $TO_SH

if [[ "${1:-missing}" == -v ]] ; then
    set -x
    TO_SH() {
        if ( ! "$TO_SH" -v "$@" ) ; then
            echo "Non-zero exit." 1>&2
            return 1
        fi
    }
else
    TO_SH() {
        echo 1>&2
        echo "> $TO_SH" "$@" 1>&2
        if ( ! "$TO_SH" "$@" ) ; then
            echo "Non-zero exit." 1>&2
            return 1
        fi
    }
fi

eval $( TO_SH test.yaml ONE=one )
echo "  ONE = 1 = ${ONE}"
unset ONE

eval $( TO_SH test.yaml FIVE=2**2+1 )
echo "  FIVE = 5 = ${FIVE}"
unset FIVE

eval $( TO_SH test.yaml scope:vars VARS_CAT=CAT )
echo "  VARS_CAT = Apollo = ${VARS_CAT}"
unset VARS_CAT

eval $( TO_SH test.yaml scope:array[2] I=item T=texture )
echo "  I = three = $I"
echo "  T = fluffy = $T"
unset I T

unset DOG CAT BIRD MOUSE
eval $( TO_SH test.yaml scope:import_from from:var_list )
echo "  DOG = $DOG"
echo "  CAT = $CAT"
if [[ "Q" != "Q${BIRD:-}" ]] ; then
    echo ERROR: Should not have exported BIRD. 1>&2
    exit 1
fi

unset DOG CAT TRUE_TEST VAR1 VAR2 VAR3
eval $( TO_SH test.yaml scope:import_from from:var_list_recurse )
echo "  DOG = $DOG"
echo "  CAT = $CAT"
echo "  TRUE_TEST = $TRUE_TEST"
echo "  VAR1 = $VAR1"
echo "  VAR2 = $VAR2"
echo "  VAR3 = $VAR3"

eval $( TO_SH test.yaml on=logical.TRUE_TEST scope:logical off=FALSE_TEST )
echo "  on = YES = $on"
echo "  off = NO = $off"
eval $( TO_SH test.yaml bool:.true.,.false. scope:logical \
            on=TRUE_TEST off=FALSE_TEST )
echo "  on = .true. = $on"
echo "  off = .false. = $off"
unset on off

eval $( TO_SH test.yaml scope:float SHORT_PI=short_pi ROUNDOFF_PI=too_long \
        float:%.20f LONG_PI=too_long NOT_FLOAT=not_float )
echo "  SHORT_PI = 3.14159 = $SHORT_PI"
echo "  floating point imprecision tests: of 3.141592653589793"
echo "    default format: $ROUNDOFF_PI"
echo "    %.20f   format: $LONG_PI"
echo "  NOT_FLOAT = 3 = $NOT_FLOAT"
unset SHORT_PI LONG_PI

eval $( TO_SH test.yaml scope:multi 'import:VAR[0-9]' )
echo "VAR TEST:"
echo "$VAR1 $VAR2 $VAR3 ${VARNOPE:-}"
echo " = value1 value2 value3 "

TO_SH test.yaml preprocess:./test.nml

TO_SH test.yaml run:success_test

TO_SH test.yaml run_ignore:failure_test

set +e
TO_SH test.yaml run:failure_test
status="$?"
echo "$status"
if [[ "$status" == 0 ]] ; then
    echo "BAD! Should have exited with non-zero status" 1>&2
    exit 1
else
    echo "Rejoice!  Exited with non-zero status!"
fi
    
