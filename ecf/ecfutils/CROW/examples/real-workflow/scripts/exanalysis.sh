#! /bin/sh

set -xue

cp -fp "$COMINtest"/member*grid .

$CROW_TO_SH expand:analysis.namelist > assimilate.nl
$CROW_TO_SH run:analysis.resources

cp -fp analysis.grid "$COMOUTtest/."
