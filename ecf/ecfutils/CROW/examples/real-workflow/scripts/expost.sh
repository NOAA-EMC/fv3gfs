#! /bin/sh

set -xue

# Load all capitalized variables from the post configuration:
eval $( $CROW_TO_SH scope:post import:"[A-Z][A-Z_]+" )

FHR=0
while [[ "$FHR" -le "$FCST_LEN" ]] ; do
    TO_SH_FHR="$CROW_TO_SH scope:post apply:fhr=$FHR"

    eval $( $TO_SH_FHR INFILE_BASE=infile )
    OUTFILE_BASE=$( echo $INFILE_BASE \
        | sed 's,fcst,post,g' | sed 's,grid,txt,g' )

    INFILE="$COMINtest/$INFILE_BASE"
    OUTFILE="$COMOUTtest/$OUTFILE_BASE"

    $USHtest/wait_for_file.sh "$INFILE" "$MIN_SIZE" "$MIN_AGE" \
        "$SLEEP_WAIT" "$MAX_WAIT_STEPS"
    cp -fp "$INFILE" .

    $TO_SH_FHR expand:namelist > post.nl
    $TO_SH_FHR run:resources > outfile

    cp -fp outfile "$OUTFILE"

    FHR=$(( FHR + FCST_FREQ_HRS ))
done
