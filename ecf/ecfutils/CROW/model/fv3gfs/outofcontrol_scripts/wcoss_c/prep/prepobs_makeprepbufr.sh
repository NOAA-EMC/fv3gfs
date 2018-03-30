#!/bin/ksh
# Run under ksh (converted to WCOSS)

####  UNIX Script Documentation Block
#
# Script name:         prepobs_makeprepbufr.sh
# Script description:  Prepares & quality controls PREPBUFR file
#
# Author:       Keyser              Org: EMC          Date: 2017-04-20
#
# Abstract: This script creates the PREPBUFR file containing observational data
#   assimilated by all versions of NCEP atmospheric analyses.  It points to BUFR
#   observational data dumps as input files.  PREPOBS_PREPDATA combines them to
#   generate an initial form of the PREPBUFR file which also contains the
#   background guess as well as the observational error field.  If tropical
#   cyclone relocation processing has previously occurred, the background global
#   guess read in by PREPOBS_PREPDATA (and later by SYNDAT_SYNDATA if it runs)
#   is the relocated guess valid at the center date/time for the PREPBUFR
#   processing.  Otherwise it is the regular (unrelocated) global atmosperic
#   guess obtained via the getges utility script.  After PREPOBS_PREPDATA runs,
#   this script can execute SYNDAT_SYNDATA to generate synthetic wind bogus
#   data, as well as their background guess and observational error fields,
#   which are appended to the PREPBUFR file. 
#
#   In the global networks the decision to append synthetic wind bogus data in
#   the SYNDATA processing is determined by the outcome of the previous
#   tropical cyclone relocation processing (if it was run).  There are three
#   possible outcomes:
#      1) If all storms in the original tcvitals file have vorticies of at
#         least medium intensity such that a relocation was previously
#         performed for each, then SYNDAT_SYNDATA will still run but will not
#         append synthetic wind bogus data to the PREPBUFR file for any storm.
#         It will input the original tcvitals file (output from qctropcy
#         processing) and (if the option is set) it will flag dropwinsonde
#         winds in the vicinity of each tropical storm in the file.
#      2) If all storms in the original tcvitals file (output from qctropcy
#         processing) have weak vorticies such that a relocation was not
#         previously performed for any, then SYNDAT_SYNDATA will run, inputting
#         the original tcvitals file, and it will append synthetic wind bogus
#         data to the PREPBUFR file for each storm in it.  It will also
#         possibly flag mass pressure and/or dropwinsonde wind reports in the
#         vicinity of each storm (if requested).
#      3) If some storms in the original tcvitals file (output from qctropcy
#         processing) have weak vorticies, such that a relocation was not
#         previously performed for them, and others have vorticies of at least
#         medium intensity, such that a relocation was previously performed for
#         these, then SYNDAT_SYNDATA will run twice.  The first time, it will
#         input the relocation-generated tcvitals file, which contains all of
#         the weak storms, and it will append synthetic wind bogus data to the
#         PREPBUFR file for each storm in it.  It will also possibly flag mass
#         pressure and/or dropwinsonde wind reports in the vicinity of each of
#         these storms (if requested).  The second time SYNDAT_SYNDATA runs, it
#         will input any storm records that were in the original tcvitals file
#         but not in the relocation-generated tcvitals file (i.e., storms with
#         vorticies of at least medium intensity).  It will not append
#         synthetic wind bogus data to the PREPBUFR file for any of these
#         storms, but it will flag dropwinsonde winds in the vicinity of each
#         storm in the original tcvitals file but not in the relocation-
#         generated tcvitals file  (if requested).
#   If this is the nam network, the only reason relocation processing would
#   have been previously run would be to update the first guess read in here by
#   PREPOBS_PREPDATA and SYNDAT_SYNDATA.  In this case, SYNDAT_SYNDATA inputs
#   the original tcvitals file (output from qctropcy processing), appends
#   synthetic wind bogus data to the PREPBUFR file for each storm in it, and
#   possibly also flags mass pressure and/or dropwinsonde wind reports in the
#   vicinity of each storm in the file (if requested).
#
#   After all of this, the script then executes a series of quality control
#   programs which can change the observation value and/or its quality marker.
#   The PREPBUFR file is set up such that all changes to data are stacked on
#   top of previous values.  Such changes are considered to be "events", with
#   the event containing an associated program code and reason code to describe
#   it.  This allows the PREPBUFR file to internally contain a record of all
#   events preformed on the observations.  This script has been designed to be
#   executed by either an "operational J-job" script, a "test J-job" script, a
#   "parallel J-job" script, or a stand-alone batch run initiated by a user.
# 
# Script history log:
# 1999-07-20  Dennis A. Keyser -- Original version for implementation
# 2000-06-14  Dennis A. Keyser -- Added the tropical cyclone relocation
#     processing
# 2001-03-20  Dennis A. Keyser -- Now gets tcvitals file for t-12 as well as
#     t-06 in tropical cyclone relocation processing and passes both to ush
#     relocate_relocate_ts.sh as new pos. parameters 3 and 4
# 2004-01-15  Dennis A. Keyser -- Reads file *aircar_status_flag* in $COMSP
#     path to see whether ARINC (primary) or AFWA (backup) reports in AIRCAR
#     dump should be read and processed as ACARS data in PREPBUFR (flag file
#     generated in upstream dump process and is based on a comparison of report
#     counts), inserts proper switch in parm cards read by PREPOBS_PREPDATA
#     program
# 2004-08-30  Dennis A. Keyser -- Connects new data dumps to PREPDATA
#     processing, copies t-3 and t+3 sigma guess files for GFS and GDAS even if
#     DO_RELOCATE = NO (unless GETGUESS = NO); Copies the "PRE-QC" snapshot of
#     the PREPBUFR file AFTER SYNDAT_SYNDATA runs (if it does) rather than
#     before it runs (ensures that the PRE-QC PREPBUFR file contains ALL of the
#     observations); Variable PRVT (observational error table file path) is now
#     read by NAM network and defaults to $FIXPREP/prepobs_errtable.nam if not
#     imported (obs. errors are now read into PREPBUFR file in NAM network in
#     preparation for the switch to the GSI analysis, the operational 3DVAR
#     analysis ignores the obs errors in PREPBUFR and still reads them in from
#     $PARMPREP/nam_errtable.r3dv)
# 2005-07-01  Dennis A. Keyser -- Logic changes to run SYNDAT_SYNDATA in all
#     networks where requested regardless of outcome of relocation processing,
#     but sets new script variable DO_BOGUS to NO if SYNDAT_SYNDATA is to NOT
#     generate synthetic wind bogus reports and append them to PREPBUFR file
#     (SYNDAT_SYNDATA program also modified to read in this variable) - change
#     needed because (if requested) SYNDAT_SYNDATA will now flag all
#     dropwinsonde wind reports in vicinity of each storm in original tcvitals
#     file, regardless of whether or not bogus winds are generated
# 2006-03-22  Dennis A. Keyser -- Accounts for possibility of split dump status
#     files (status1 and status2) at the time this runs {in the test for the
#     presence of the dump status file(s)}
# 2006-06-13  Dennis A. Keyser -- Adds dump file "wdsatr" to default BUFRLIST
#      value and assigns it to unit 38 read in to PREPOBS_PREPDATA; Removed
#      tropical cyclone relocation processing, this is now done (if requested)
#      in a new script called tropcy_relocate.sh which runs in the new
#      TROPCY_QC_RELOC job prior to the PREP job that executes this script
#      (TROPCY_QC_RELOC first performs qctropcy processing, this was moved from
#      the DUMP job) - this was done to allow the TROPCY_QC_RELOC job to run at
#      the same time as the DUMP job in order to speed up overall obs
#      processing and remove variability in the PREP job executing this script
#      (i.e., this job had run faster when no tropical storms were present)
# 2007-09-14  Dennis A. Keyser -- Replaced "export XLFUNIT_xx=<filename>" with
#      "ln .sf <filename> fort.xx" in preparation for PREPOBS_PREPDATA
#      interfacing with global spectral guess files using sigio routines (via
#      W3LIB routine GBLEVENTS - sigio requires explicit open statements in the
#      code and this conflicts with XLFUNIT statements; Removed test on
#      existence of status2 file from NAM_DUMP2 and NDAS_DUMP2 jobs since dump
#      files here (currently only "nexrad") are not processed into the PREPBUFR
#      file - PREP job initiation may soon no longer be dependent upon
#      completion of DUMP2 job in NAM and NDAS networks; in the case where an
#      input (normally, pre-QC) PREPBUFR file is passed into the script via the
#      variable PREPBUFR_IN, it had been assumed that this file had already
#      been run through SYNDATA processing (but that was not the case prior to
#      12Z 25 Jan 2005) - this script changed to use the value of variable
#      SYNDATA to determine if the file in PREPBUFR_IN should be run through
#      SYNDATA processing (i.e., if SYNDATA=YES, run it through SYNDATA
#      processing) (this change will allow reanalysis runs prior to 12Z 25 Jan
#      2005 to work properly)
# 2008-09-25  Dennis A. Keyser -- Added dump file "ascatw" to default BUFRLIST
#      value and assigns it to unit 39 read in to PREPOBS_PREPDATA; in
#      preparation for future NRL aircraft QC code NRLACQC, added new script
#      variables NRLACQC (def=NO), USHNQC (def=${HOMEALL}/ush), NQCX
#      (def=$EXECPREP/prepobs_nrlacqc) and NQCC
#      (def=$PARMPREP/prepobs_nrlacqc.${NET}.parm"), if NRLACQC=YES will
#      execute script USHNQC to perform NRL aircraft QC (not yet ready)
# 2011-10-14  D.A. Keyser -- Updated to handle new "rap" (Rapid Refresh)
#    network and its model runs "rap", "rap_p" and "rap_e"
# 2012-05-09 S. Bender/D. Keyser -- Removed all prior references to "NRL"
#      aircraft QC script variables (never actually used) since the NRL
#      aircraft QC nomenclature is being dropped in place of the existing
#      PREPACQC nomenclature and will use its existing script variables;
#      removed all references to the ACARSQC processing since it is no longer
#      executed (ACARS QC is now performed within the revamped PREPACQC
#      processing); removed script variables no longer used by the new version
#      of the PREPACQC processing; added new script variables which are
#      associated with the new program PREPOBS_PREPACPF which now runs as a
#      second program within the PREPACQC processing (after program
#      PREPOBS_PREPACQC) in the ush script prepobs_prepacqc.sh {PROCESS_ACQC
#      (def=YES), PROCESS_ACPF (def=YES), DICTPREP (def=$HOMEALL/dictionaries),
#      DICT (def=$DICTPREP/metar.tbl), APFX (def=$EXECPREP/prepobs_prepacpf),
#      and the new second argument "$DATA/adpsfc" passed to
#      prepobs_prepacqc.sh}
# 2013-03-05  D.A. Keyser -- Modified to properly run on WCOSS system: replaced
#      all usage of "timex" with "time -p."; replaced script variables
#      XLFUNIT_n with FORTn (where n is the unit number connected to the
#      filename defined by the variable FORTn) - needed because ifort uses
#      FORTn; script is now set to run under ksh shell as the default; added
#      script variable "BACK" which, when YES, threads the mp_prepdata herefile
#      into background shells that run simultaneously (an alternative option
#      to poe which is not ready on WCOSS); touches all dump files not included
#      in BUFRLIST so that they will not cause a read error if PREPOBS_PREPDATA
#      tries to read them
# 2014-01-15  S. Melchior -- Placed into new OBSPROC_PREP vertical directory
#      structure/environmental equivalence paradigm.  As a result: imports new
#      environment variable $HOMEobsproc_prep which points to directory path for
#      generic prep subdirectories under version control (in production this is
#      normally /nwprod/obsproc_prep.vX.Y.Z where X.Y.Z is version number being
#      used, usually the latest); and imports new environment variable
#      $HOMEobsproc_network which points to directory path for network-specific
#      prep subdirectories under version control (in production this is normally
#      /nwprod//obsproc_NETWORK.vX.Y.Z where NETWORK is, e.g., global, namp, rap,
#      rtma, urma, and X.Y.Z is version number being used, usually the latest) -
#      these replace /nw${envir} in order to point to files moved from 
#      horizontal to vertical directory structure.
# 2014-02-25  D.A. Keyser -- Removed all references to RUC.  Removed option
#      to run on MACHINE=sgi - this is obsolete (as a result variables $MACHINE
#      and $HOMEALL are no longer used in this script).  Replaced variable
#      $EXECUTIL with $utilexec for directory path to utility program ndate
#      (both were exported from job scripts with same value, $EXECUTIL has now
#      been removed from all job scripts).  Removed all references to "cdc"
#      network (this is obsolete).
# 2014-07-23  D.A. Keyser -- Imported script environment variable DICTPREP now
#      defaults to new vertical structure directory path location for metar.tbl
#      dictionary, /nw${envir}/decoders/decod_shared/dictionaries, rather than
#      old horizontal structure location, /nw${envir}/dictionaries (the latter
#      will be removed in September 2014).
# 2016-02-05 JWhiting -- Use NCO-established variables to point to root
#      directories for main software components and input/output directories in
#      order to run on WCOSS Phase 1 or Phase 2 (here, $COMROOT which replaces
#      hardwire to "/com", $NWROOT which replaces hardwire to "/nwprod" in
#      comments only).  Use NCO-established variables (presumably obtained from
#      modules) to point to prod utilities [here, $NDATE from module prod_util
#      (default or specified version, loaded in each network which executes this
#      script) which replaces executable ndate in non-versioned, horizontal
#      structure utility directory path defined by imported variable $utilexec].
# 2016-04-29 D.A. Keyser  -- Updated logic such that when tropical cyclone
#      relocation has not run, a first guess is required, the network is gfs or
#      gdas, but the cycle time is not 00, 06, 12 or 18z, no attempt will be
#      made to obtain a guess 3-hrs before and after cycle time (since it can
#      fail).  Instead this is treated the same as any 3- or 1-hrly cycle run
#      (like rap, e.g.) meaning two guess files will be obtained at the
#      spanning 3 hour interval around any cycle time not a multiple of 3 hrs.
#      BENEFIT: Allows future hourly WAM model to run properly.
# 2016-07-12  D.C. Stokes -- Reinstated poe option to run multiple instances
#      of the PREPDATA processing script in parallel. New variable $launcher 
#      defines the parallel scripting launch mechanism (description below).
#      Added logic to create scaled down versions of err_chk and err_exit 
#      scripts if they don't exist in the working directory and eliminated 
#      similar blocks of logic that had been repeated throughout the script.
#      Updated USHGETGES default to pick up more recent versions of getges.sh.
# 2017-02-07  D.C. Stokes -- Updated to run on Cray-XC40 as well as iDataPlex.
#      If on Cray-XC40, default parallel scripting launching mechanism is cfp 
#      inovked by aprun. Variable name used for launching mechanism changed from
#      "launcher" to "launcher_PREP".  Variable COMDATEROOT is now the primary
#      default for the root of the directory containing NCEP date files.  The
#      variable NWROOTp1 is now the default root for directory DICTPREP.  Logic
#      used to determine if $COMSP points to production "com" directory was
#      updated to recognize full path name (as needed on luna/surge).
# 2017-03-19  D.C. Stokes/D.A. Keyser -- Updated to input nemsio atmopheric 
#      guess files -or- the older sigio atmospheric files.  The nemsio option
#      is triggered by flag NEMSIO_IN=.true.  For nemsio runs, a single guess
#      file valid at the prepbufr center time is picked up, even for runs with
#      center time that is not a multiple of 3.  Also the dbn_alert subtype is
#      now dependent upon $RUN (for transition from "gdas1" to "gdas").
# 2017-04-20  D.C. Stokes -- Relocated assignments of variable stype to ensure
#      it always passes the proper value to the getges utility script.
#     
#
# Usage:  prepobs_makeprepbufr.sh yyyymmddhh
#
#   Input script positional parameters:
#     1             String indicating the center date/time for the PREPBUFR
#                   processing <yyyymmddhh> - if missing, then this time
#                   is obtained from the ${COMDATEROOT}/date/$cycle file
#
#   Imported Shell Variables:
#
#     These must ALWAYS be exported to this script by the parent script --
#
#     COMROOT       Root to input/output "com" directory (in production,
#                   normally "/com", "/com2", or "/gpfs/hps/nco/ops/com")
#     NSPLIT        Number of parts into which the PREPDATA processing shell
#                   script (herefile MP_PREPDATA) will be split in order to
#                   run in parallel for computational efficiency (either using
#                   multiple tasks when POE is not "NO" or in background threads
#                   when BACK is "YES")
#                   NOTE : This is required ONLY if the imported shell variable
#                          POE is not "NO" (see below) or the imported shell
#                          variable BACK is "YES" (see below) (i.e., a parallel
#                          environment), and the imported shell variable
#                          PREPDATA=YES (see below)
#     NET           String indicating system network {either "gfs", "gdas",
#                   "cdas", "nam", "rap", "rtma" or "urma"}
#                   NOTE : NET is changed to gdas in the parent Job script for
#                          RUN=gdas or RUN=gdas1 (was gfs) 
#     RUN           String indicating model run {either "gfs", "gdas", "gdas1",
#                         "cdas", "nam", "ndas", "rap", "rap_p", "rap_e",
#                         "rtma", or "urma"}
#     cycle         String indicating the center cycle hour for PREPBUFR
#                   processing {"txxz", where xx is two-digit hour of the day
#                   (UTC)}
#                   NOTE : This is required ONLY if input script positional
#                          parameter 1 is missing (see above)
#     DATA          String indicating the working directory path (usually a
#                   temporary location)
#     COMSP         String indicating the directory/filename path to input BUFR
#                   observational data dumps, tropical cyclone location
#                   (tcvitals) files, global atmos guess files, and status
#                   files (e.g., "$COMROOT/gfs/prod/gfs.20060612/gfs.t12z.")
#     DBNROOT       String indicating directory path to bin/dbn_alert file
#                   location
#                   NOTE : This is required ONLY if the imported shell variable
#                          SENDDBN is "YES" (see below)
#     job         - String indicating job name (e.g., 'gdas_prep_12')
#                   NOTE : This is required ONLY if the imported shell variable
#                          SENDDBN is "YES" (see below)
#     $HOMEobsproc_prep    - string indicating directory path to generic prep
#                            subdirectories under version control
#                            (in production this is normally
#                            ${NWROOT}/obsproc_prep.vX.Y.Z where X.Y.Z is
#                            version number being used, usually the latest)
#     $HOMEobsproc_network - string indicating directory path to network-
#                            specific prep subdirectories under version control
#                            (in production this is normally
#                            ${NWROOT}/obsproc_NETWORK.vX.Y.Z where NETWORK is,
#                            e.g., global, nam, rap, rtma, urma, and X.Y.Z is
#                            version number being used, usually the latest)
#
#     These will be set to their default value in this script if not exported
#      to this script by the parent script --
#
#     SITE          Site name (may have been set by local shell startup script)
#                   Default is ""
#     sys_tp        System type and phase.  If not imported, an attempt is made
#                   to set it using getsystem.pl (an NCO prod_util script).
#                   A failed attempt results in an empty string.
#     NEMSIO_IN     Flag that if ".true." indicates that nemsio atmospheric 
#                   background fields will be input rather than sigio.
#                   Default is ""
#     SENDDBN       String indicating whether or not to alert an output file to
#                   the NWS/TOC (= "YES" - invoke alert; anything else - do not
#                   invoke alert)
#                   Default is "NO"
#     NPROCS        Number of "poe" tasks to use for mpmd (must be .GE. $NSPLIT)
#                   NOTE : This is applicable ONLY if the imported shell
#                          variable POE is not "NO" (see below) and variable 
#                          launcher_PREP is not "cfp" or "aprun" (see below) and
#                          the imported shell variable PREPDATA=YES (see below)
#                   For LSF jobs, the count of hosts listed in string $LSB_HOSTS
#                   will be used to set NPROCS (overriding any imported value).
#                   Default is "$NSPLIT"
#     envir         String indicating environment under which job runs ('prod'
#                   or 'test')
#                   Default is "prod"
#     envir_getges  String indicating environment under which GETGES utility
#                   ush runs (see getges.sh docblock for more information)
#                   Default is "$envir"
#     network_getges
#                   String indicating job network under which GETGES utility
#                   ush runs (see getges.sh docblock for more information)
#                   Default is "global" unless the center PREPBUFR processing
#                   date/time is not a multiple of 3-hrs and the global guess is
#                   sigio-based, then the default is "gfs"
#     pgmout        String indicating file containing standard output (output
#                   always contatenated onto this file)
#                   Default is "/dev/null"
#     tstsp         String indicating the directory/filename path to one or
#                   more BUFR observational data dumps and/or tropical cyclone
#                   location (tcvitals) files and/or global atmos guess files
#                   and/or status files that are to override the corresponding
#                   file in $COMSP (this should be imported with the same
#                   naming convention as $COMSP; e.g.,
#                   "/gpfstmp/wx22dk/test_dump/ndas.20060612/ndas.t12z." -
#                   (if tstsp is not imported, the default is used and no
#                   overriding file would exist; if tstsp is imported then any
#                   file found would override the correspoding file in $COMSP)
#                   Default is "/tmp/null/"
#     tmmark      - string indicating hour for center PREPBUFR processing date/
#                   time relative to the analysis time embedded in $tstsp or
#                   $COMSP (e.g., "tm12", "tm09", "tm06", "tm03", "tm00")
#                   Default is "tm00"
#     BUFRLIST      String indicating list of BUFR data dump file names to
#                   process
#                   Default is "adpupa proflr aircar aircft satwnd adpsfc \
#                   sfcshp sfcbog vadwnd goesnd spssmi erscat qkswnd msonet \
#                   gpsipw rassda wdsatr ascatw"
#     POE           String indicating whether or not to use a poe-like launcher
#                   to spread instances of the PREPBUFR processing herefile 
#                   MP_PREPDATA over multiple pes in parallel. (= "NO" - 
#                   do not invoke invoke "poe"; anything else - invoke "poe")
#                   Default is "YES"
#     launcher_PREP Parallel scripting launch tool. Settings are in place for
#                   aprun, mpirun.lsf, and cfp but a different tool can be
#                   specified.
#                   NOTE : This is applicable ONLY if the imported shell
#                          variable POE is not "NO" and the imported shell
#                          variable PREPDATA=YES (see below)
#                   Default on Cray-XC40 is "aprun". Otherwise: "mpirun.lsf"
#     BACK          String indicating whether or not to run background shells
#                   (on the same task) for the PREPBUFR processing (= "YES" -
#                   run background shells; anything else - do not run
#                   background shells). IF BACK=YES on Cray-XC40, the shells
#                   are invoked by aprun.
#     USHSYND       String indicating directory path for SYNDATA ush file
#                   Default is "${HOMEobsproc_prep}/ush"
#     USHPREV       String indicating directory path for PREVENTS ush file
#                   Default is "${HOMEobsproc_prep}/ush"
#     USHCQC        String indicating directory path for CQCBUFR ush file
#                   Default is "${HOMEobsproc_prep}/ush"
#     USHPQC        String indicating directory path for PROFCQC ush file
#                   Default is "${HOMEobsproc_prep}/ush"
#     USHVQC        String indicating directory path for CQCVAD ush file
#                   Default is "${HOMEobsproc_prep}/ush"
#     USHAQC        String indicating directory path for PREPACQC ush file
#                   Default is "${HOMEobsproc_prep}/ush"
#     USHOIQC       String indicating directory path for OIQCBUFR ush file
#                   Default is "${HOMEobsproc_prep}/ush"
#     EXECPREP      String indicating directory path for PREPOBS executables
#                   Default is "${HOMEobsproc_prep}/exec"
#     PARMPREP      String indicating directory path for PREPOBS parm files
#                   Default is "${HOMEobsproc_network}/parm"
#     FIXPREP       String indicating directory path for PREPOBS fix-field
#                   files
#                   Default is "${HOMEobsproc_prep}/fix"
#     DICTPREP      String indicating directory path for PREPOBS dictionary
#                   files
#                   Default is "${NWROOTp1}/decoders/decod_shared/dictionaries"
#     EXECSYND      String indicating directory path for SYNTHETIC data
#                   executables
#                   Default is "${HOMEobsproc_prep}/exec"
#     PARMSYND      String indicating directory path for SYNTHETIC parm files
#                   Default is "${HOMEobsproc_network}/parm"
#     FIXSYND       String indicating directory path for SYNTHETIC data fix-
#                   field files
#                   Default is "${HOMEobsproc_prep}/fix"
#     GETGUESS      String: if = "YES" will encode first guess (background)
#                   values interpolated by the program PREPOBS_PREPDATA to
#                   observation locations in the PREPBUFR file for use by the
#                   q.c. programs.  This guess is always from a global atmos
#                   guess file valid at the center PREPBUFR processing date/
#                   time or from an interpolated guess obtained from global
#                   atmos guess files valid at times 3-hours apart which span
#                   the PREPBUFR processing date/time (the latter is performed
#                   by the program PREPOBS_PREPDATA and occurs when the guess
#                   files are sigio-based and the PREPBUFR date/time hour is not
#                   a multiple of 3, e.g. 02Z rap or tm04 nam catchup runs). The
#                   guess file (or files) may be obtained in one of two ways:
#                       1) From pre-existing files in the working directory
#                          $DATA called sgesprep and sgesprepA (either copied
#                          there prior to the execution of this script, or
#                          copied there earlier in this script from either
#                          $tstsp, or if not found there, $COMSP which was
#                          populated by the previous running of tropical
#                          cyclone relocation processing
#                           NOTE 1: sgesprepA is needed only when the guess is
#                                   sigio-based and the PREPBUFR processing
#                                   date/time is not a multiple of 3-hrs.
#                           NOTE 2: if previous tropical cyclone relocation
#                                   processing was run, then an sgesprepA file
#                                   is NEVER generated, not a problem since
#                                   previous tropical cyclone relocation
#                                   processing is not run in rap, rap_p or
#                                   rap_e runs
#                       2) Via the execution of the GETGES utility ush to
#                          obtain sgesprep (if pre-existing file $DATA/sgesprep
#                          does not exist), and possibly via the execution of
#                          the GETGES utility ush to obtain sgesprepA (if
#                          PREPBUFR processing date/time is not a multiple of
#                          3-hrs and the global guess is sigio-based, and the
#                          pre-existing file $DATA/sgesprepA does not exist)
#                   Default is "YES"
#                   NOTE: If GETGUESS=NO, then the program PREPOBS_PREPDATA
#                         will NOT call w3emc routine GBLEVENTS to perform
#                         "prevents" processing
#     PREPDATA      String: if = "YES" will perform PREPDATA processing
#                   (in either a parallel or serial environment depending upon
#                   the values for POE and BACK)
#                   Default is "YES"
#     SYNDATA       String: if = "YES" will attempt to perform synthetic bogus
#                   processing (generation of synthetic bogus winds to be
#                   appended to PREPBUFR file and, possibly, flagging of mass
#                   pressure data "near" storms; and, possibly, flagging of
#                   dropwinsonde wind data "near" storms)
#                   Default is "YES"
#     DO_QC         String: if = "YES" will perform quality control
#                   Default is "YES"
#     PREVENTS      String: if = "YES" will encode background and obs. errors
#                   into PREPBUFR file (usually this should be "NO" since the
#                   programs PREPOBS_PREPDATA and SYNDAT_SYNDATA normally are
#                   set to perform this function)
#                   NOTE: Only invoked if DO_QC=YES
#                   Default is "NO"
#     CQCBUFR       String: if = "YES" will complex quality control radiosonde
#                   data
#                   NOTE: Only invoked if DO_QC=YES
#                   Default is "YES"
#     PROFCQC       String: if = "YES" will quality control wind profiler data
#                   NOTE: Only invoked if DO_QC=YES
#                   Default is "YES"
#     CQCVAD        String: if = "YES" will quality control VAD wind data
#                   NOTE: Only invoked if DO_QC=YES
#                   Default is "YES"
#     PREPACQC      String: if = "YES" will quality control aircraft data
#                   NOTE: Only invoked if DO_QC=YES
#                   Default is "YES"
#     PROCESS_ACQC  String: if = "YES" will execute PREPOBS_PREPACQC program as
#                   part of PREPACQC processing
#                   NOTE: Only invoked if PREPACQC=YES
#                   Default is "YES"
#     PROCESS_ACPF  String: if = "YES" will execute PREPOBS_PREPACPF program as
#                   part of PREPACQC processing
#                   NOTE: Only invoked if PREPACQC=YES
#                   Default is "YES"
#     OIQCBUFR      String: if = "YES" will perform final oi-based quality
#                   control on all data
#                   NOTE: Only invoked if DO_QC=YES
#                   Default is "YES"
#     MPCOPYX       String indicating executable path for PREPOBS_MPCOPYBUFR
#                   program
#                   Default is "$EXECPREP/prepobs_mpcopybufr"
#     PRPX          String indicating executable path for PREPOBS_PREPDATA
#                   program
#                   Default is "$EXECPREP/prepobs_prepdata"
#     errPREPDATA_limit
#                   String indicating the highest allowed foreground exit
#                   status for program PREPOBS_PREPDATA (any exit status higher
#                   than this is considered a failure)
#                   (Note: errPREPDATA_limit=1 is ALWAYS considered a FAILURE)
#                   Default is "0"
#     PRPC          String indicating data card path for PREPOBS_PREPDATA
#                   program
#                   Default is "$PARMPREP/prepobs_prepdata.${NET}.parm"
#     PRPT          String indicating bufrtable file path for PREPOBS_PREPDATA
#                   program
#                   Default is "$FIXPREP/prepobs_prep.bufrtable"
#     LANDC         String indicating land/sea mask file path for
#                   PREPOBS_PREPDATA program
#                   Default is "$FIXPREP/prepobs_landc"
#     PRVT          String indicating observational error table file path for
#                   PREPOBS_PREPDATA, SYNDAT_SYNDATA and PREPOBS_PREVENTS
#                   programs (used by GBLEVENTS subroutine)
#                   NOTE: Only read by gdas, gfs, cdas and nam networks
#                   If imported "NET=gdas" or "NET=gfs", default is
#                   "$HOMEobproc_network/fix/prepobs_errtable.global";
#                   if imported "NET=cdas", default is
#                   "$HOMEobsproc_network/fix/prepobs_errtable.cdas";
#                   if imported "NET=nam", default is
#                   "$HOMEobsproc_network/fix/prepobs_errtable.nam"
#                   otherwise, default is "$DATA/scratch.PRVT" a null file
#     LISTHDX       String indicating executable path for PREPOBS_LISTHEADERS
#                   program
#                   Default is "$EXECPREP/prepobs_listheaders"
#     MONOBFRX      String indicating executable path for PREPOBS_MONOPREPBUFR
#                   program
#                   Default is "$EXECPREP/prepobs_monoprepbufr"
#     SYNDX         String indicating executable path for SYNDAT_SYNDATA
#                   program
#                   Default is "$EXECSYND/syndat_syndata"
#     SYNDC         String indicating data card path for SYNDAT_SYNDATA program
#                   Default is "$PARMSYND/syndat_syndata.${NET}.parm"
#     PREX          String indicating executable path for PREPOBS_PREVENTS
#                   program
#                   Default is "$EXECPREP/prepobs_prevents"
#     PREC          String indicating data card path for PREPOBS_PREVENTS
#                   program
#                   Default is "$PARMPREP/prepobs_prevents.${NET}.parm"
#     AQCX          String indicating executable path for PREPOBS_PREPACQC
#                   program
#                   Default is "$EXECPREP/prepobs_prepacqc"
#     AQCC          String indicating data card path for PREPOBS_PREPACQC
#                   program
#                   Default is "$PARMPREP/prepobs_prepacqc.${NET}.parm"
#     APFX          String indicating executable path for PREPOBS_PREPACPF
#                   program
#                   Default is "$EXECPREP/prepobs_prepacpf"
#     DICT          String indicating METAR station dictionary path for
#                   PREPOBS_PREPACPF program
#                   Default is "$DICTPREP/metar.tbl"
#     PQCX          String indicating executable path for PREPOBS_PROFCQC
#                   program
#                   Default is "$EXECPREP/prepobs_profcqc"
#     PQCC          String indicating data card path for PREPOBS_PROFCQC
#                   program
#                   Default is "$PARMPREP/prepobs_profcqc.${NET}.parm"
#     VQCX          String indicating executable path for PREPOBS_CQCVAD
#                   program
#                   Default is "$EXECPREP/prepobs_cqcvad"
#     CQCX          String indicating executable path for PREPOBS_CQCBUFR
#                   program
#                   Default is "$EXECPREP/prepobs_cqcbufr"
#     CQCC          String indicating data card path for PREPOBS_CQCBUFR
#                   program
#                   Default is "$PARMPREP/prepobs_cqcbufr.${NET}.parm"
#     CQCS          String indicating statbge path for PREPOBS_CQCBUFR program
#                   Default is "$FIXPREP/prepobs_cqc_statbge"
#     OIQCX         String indicating executable path for PREPOBS_OIQCBUFR
#                   program
#                   Default is "$EXECPREP/prepobs_oiqcbufr"
#     OIQCT         String indicating observational error table file path for
#                   PREPOBS_OIQCBUFR program
#                   NOTE: If imported "NET=cdas", default is
#                   "$HOMEobsproc_network/fix/prepobs_oiqc.oberrs.cdas"; 
#                   otherwise default is
#                   "$HOMEobsproc_network/fix/prepobs_oiqc.oberrs"
#
#     These do not have to be exported to this script.  If they are, they will
#      be used by the script.  If they are not, they will be skipped
#      over by the script.
#
#     PREPBUFR_APP  String indicating path to output PREPBUFR file for
#                   PREPOBS_PREPDATA program.
#                   If present and POE is "NO" and BACK is not "YES"  (i.e., a
#                    serial environment), PREPOBS_PREPDATA will append all
#                    output BUFR messages to a copy of this file (prepda) in
#                    the current working directory, using the internal BUFR
#                    mnemonic table in the first several BUFR messages at the
#                    top of the file
#                    NOTE 1: In this case, it is assumed the the switch APPEND
#                            is set to TRUE in the parm cards $PRPC (careful,
#                            if APPEND is FALSE, the original copy of
#                            $PREPBUFR_APP will be wiped out and the case below
#                            will occur)
#                    NOTE 2: When POE is not "NO" or BACK is "YES"  (i.e., a
#                            parallel environment), appending makes no sense
#                            because the original output PREPBUFR file is
#                            monolithic
#                   If not present or POE is not "NO" or BACK is "YES" (i.e., a
#                    parallel environment), PREPOBS_PREPDATA will write all
#                    output BUFR messages to a new file (prepda) in the current
#                    working directory using the external BUFR mnemonic table
#                    in the file $PRPT
#                    NOTE 3: In this case, it is assumed the the switch APPEND
#                            is set to FALSE in the parm cards $PRPC (careful,
#                            if APPEND is TRUE, PREPOBS_PREPDATA will abort
#                            because the original empty PREPBUFR file has no
#                            internal BUFR mnemonic table)
#     PREPBUFR_IN   String indicating path to input PREPBUFR file
#                   If present, this file will be used by SYNDAT_SYNDATA (if
#                    SYNDATA=YES - see @ below) and by all applicable Q.C.
#                    programs (set to to be invoked here) rather than the
#                    PREPBUFR file generated in this script by PREPOBS_PREPDATA
#                    (normally this would be used when PREPDATA=NO)
#                         @ - if the PREPBUFR_IN target file is obtained from
#                           ${COMROOT}/*/prod/*.YYYYMMDD/*.tCCz.prepbufr_pre-qc,
#                             then for all runs on and after 12Z 25 Jan 2005,
#                             SYNDATA should be NO because the target files
#                             will already contain synthetic bogus data;
#                             if the PREPBUFR_IN target file is obtained from
#                           ${COMROOT}/*/prod/*.YYYYMMDD/*.tCCz.prepbufr_pre-qc,
#                             then for all runs prior to 12Z 25 Jan 2005,
#                             SYNDATA should be YES because the target files
#                             will not have contain synthetic bogus data.
#                   If not present, then the PREPBUFR file generated in this
#                    script by PREPOBS_PREPDATA and possibly appended to by
#                    SYNDAT_SYNDATA is passed on as input to all applicable
#                    Q.C. programs
#     jlogfile      String indicating path to joblog file
#
#     These do not have be exported to this script.
#
#     COMDATEROOT   Primary default for the root of the directory containing
#                   produciton date files.
#
#     NWROOTp1      Root directory for production software on WCOSS Phase 1.
#
#     USHGETGES     String indicating directory path for GETGES utility script.
#                   Default is $HOMEobsproc_prep/ush.
#
#     GETGESprep    GETGES utility script. If NEMSIO_IN=.true.,  defaults to:
#                       $USHGETGES/getges.sh
#                   otherwise, defaults to:
#                       $USHGETGES/getges_sig.sh 
#
#     PREPDATAtpn   Tasks per node when invoking cfp on Cray-XC40.  Will be
#                   computed if needed but was not imported.
#                   
#     These do not have to be exported to this script.  If they are, they will
#      be passed on to the script $USHCQC/prepobs_cqcbufr.sh. They are not used
#      by this script.
#
#     PRPI_m24      See documentation in $USHCQC/prepobs_cqcbufr.sh
#     PRPI_m12      See documentation in $USHCQC/prepobs_cqcbufr.sh
#     PRPI_p12      See documentation in $USHCQC/prepobs_cqcbufr.sh
#     PRPI_p24      See documentation in $USHCQC/prepobs_cqcbufr.sh
#
#   Exported Shell Variables:
#     CDATE10       String indicating the center date/time for the PREPBUFR
#                   processing <yyyymmddhh>
#     SGES          Either ...
#                    1) String indicating the full path name for global
#                       sigio-based or nemsio-based guess file valid at the
#                       center PREPBUFR processing date/time (in which case the
#                       center PREPBUFR processing date/time is a multiple of
#                       3-hrs, or for any PREPBUFR center hour if global guess
#                       is nemsio-based)  - This guess file will be encoded
#                       into the PREPBUFR file for use by the q.c. programs.
#                             -- or --
#                    2) String indicating the full path name for the global
#                       atmosperic guess file valid at the nearest cycle time
#                       prior to the center PREPBUFR processing date/time which
#                       is a multiple of 3 (in which case the center PREPBUFR
#                       processing date/time is not a multiple of 3-hrs and the
#                       global guess is sigio-based) - A linear interpolation
#                       (of the spectal coefficients) between this file and the
#                       guess file indicated by SGESA case 2 below will be
#                       performed by program PREPOBS_PREPDATA and encoded into
#                       the PREPBUFR file for use by the q.c. programs.  The
#                       SGES file is always from the GFS in this case.
#                     NOTE 1: Only case 1 above is valid when tropical cyclone
#                             relocation processing previously occurred.
#                     NOTE 2: Case 2 above is necessary because the w3emc lib
#                             routine gblevents called by PREPOBS_PREPDATA
#                             expects that sigio-based guess files will only
#                             have valid hours which are a multiple of 3
#                     NOTE 3: Only case 1 above is valid when global guess is
#                             nemsio-based.
#     SGESA         Either ...
#                    1) String set to "/dev/null" for case 1 of SGES above
#                       (default)
#                             -- or --
#                    2) String indicating the full path name for the global
#                       sigma guess file valid at the nearest cycle time after
#                       the center PREPBUFR processing/date time which is a
#                       multiple of 3 for case 2 of SGES above - A linear
#                       interpolation (of the spectal coefficients) between
#                       this guess file and the guess file indicated by SGES
#                       above (see case 2 for SGES) will be performed by the
#                       program PREPOBS_PREPDATA and encoded into the PREPBUFR
#                       file for use by the q.c. programs.  The SGESA file is
#                       always from the GFS in this case and its forecast hour
#                       is 3-hrs later than the SGES file (thus both initiate
#                       at the same time).
#                     NOTE 1: Only case 1 above is valid when tropical cyclone
#                             relocation processing previously occurred.
#                     NOTE 2: Case 2 above is necessary because the w3emc lib
#                             routine gblevents called by PREPOBS_PREPDATA
#                             expects that sigio-based guess files will only
#                             have valid hours which are a multiple of 3
#                     NOTE 3: Only case 1 above is valid when global guess is
#                             nemsio-based.
#   
#
#   Modules and files referenced:
#     herefiles  : $DATA/MP_PREPDATA
#                  $DATA/MERGE_MSGS
#     scripts    : $USHGETGES/getges.sh
#                  $USHGETGES/getges_sig.sh
#                  $USHSYND/prepobs_syndata.sh
#                  $USHPREV/prepobs_prevents.sh
#                  $USHCQC/prepobs_cqcbufr.sh
#                  $USHPQC/prepobs_profcqc.sh
#                  $USHVQC/prepobs_cqcvad.sh
#                  $USHAQC/prepobs_prepacqc.sh
#                  $USHOIQC/prepobs_oiqcbufr.sh
#                  $DATA/postmsg (required ONLY if "$jlogfile" is present)
#                  $DATA/prep_step {here and by referenced script(s)}
#                  $DATA/err_exit
#                  $DATA/err_chk {here and by referenced script(s)}
#                  (NOTE: The last three scripts above are NOT REQUIRED
#                         utilities. If $DATA/prep_step not found, a scaled down
#                         version of it is executed in-line. If $DATA/err_exit
#                         or $DATA/err_chk are not found, scaled down versions,
#                         created in-line, are executed.
#     executables: $NDATE (from prod_util module)
#     programs   :
#          PREPOBS_MPCOPYBUFR   - executable: $MPCOPYX
#          PREPOBS_PREPDATA     - executable: $PRPX
#                                 land/sea mask: $LANDC
#                                 bufr mnemonic user table: $PRPT
#                                 obs. error table: $PRVT
#                                 data cards: $PRPC
#          PREPOBS_LISTHEADERS  - executable: $LISTHDX
#          PREPOBS_MONOPREPBUFR - executable: $MONOBFRX
#          SYNDAT_SYNDATA       - executable: $SYNDX
#                                 T126 gaussian land/sea mask:
#                                   $FIXSYND/syndat_syndata.slmask.t126.gaussian
#                                 weights: $FIXSYND/syndat_weight
#                                 obs. error table: $PRVT
#                                 data cards: $SYNDC
#          PREPOBS_PREVENTS     - executable: $PREX
#                                 obs. error table: $PRVT
#                                 data cards: $PREC
#          PREPOBS_PREPACQC     - executable: $AQCX
#                                 data cards: $AQCC
#          PREPOBS_PREPACPF     - executable: $APFX
#                                 dictionary: $DICT
#          PREPOBS_PROFCQC      - executable: $PQCX
#                                 data cards: $PQCC
#          PREPOBS_CQCVAD       - executable: $VQCX
#          PREPOBS_CQCBUFR      - executable: $CQCX
#                                 data cards: $CQCC
#          PREPOBS_OIQCBUFR     - executable: $OIQCX
#                                 obs. error table: $OIQCT
#
# Remarks:
#
#   Condition codes
#      0 - no problem encountered
#     >0 - some problem encountered
#
# Attributes:
#   Language: Korn shell under linux
#   Machine:  NCEP WCOSS
#
####

set -aux

NEMSIO_IN=${NEMSIO_IN:=""}
jlogfile=${jlogfile:=""}
SENDDBN=${SENDDBN:-NO}

if [ ! -d $DATA ] ; then mkdir -p $DATA ;fi

cd $DATA

qid=$$

#####################################################
#####################################################
# create error check and exit utilities if necessary.
# (as may be the case for some developer runs)
#####################################################

if [ ! -x $DATA/err_exit ]; then
cat <<\EOFerrexit > $DATA/err_exit
   set -x
   if [ -n "$LSB_JOBID" ]; then
      bkill $LSB_JOBID
      sleep 60
      date
   else
      set -e
      kill -n 9 $qid
   fi
   exit 7    # for extra measure
EOFerrexit
chmod 775 $DATA/err_exit
fi

if [ ! -x $DATA/err_chk ]; then
cat <<\EOFerrchk > $DATA/err_chk
   set -x
   if [ "$err" != '0' ]; then
      $DATA/err_exit
   fi
EOFerrchk
chmod 775 $DATA/err_chk
fi

#####################################################
#####################################################


#  determine local system name and type if available
#  -------------------------------------------------
SITE=${SITE:-""}
sys_tp=${sys_tp:-$(getsystem.pl -tp)}
getsystp_err=$?
if [ $getsystp_err -ne 0 ]; then
   msg="***WARNING: error using getsystem.pl to determine system type and phase"
   [ -n "$jlogfile" ] && $DATA/postmsg "$jlogfile" "$msg"
fi
echo sys_tp is set to: $sys_tp

#-------------------------------------------------------------------------------

#  obtain the center date/time for PREPBUFR processing
#  ---------------------------------------------------

if [ $# -ne 1 ] ; then
   cp ${COMDATEROOT:-$COMROOT}/date/$cycle ncepdate
   err0=$?
   CDATE10=`cut -c7-16 ncepdate`
else 
   CDATE10=$1
   if [ "${#CDATE10}" -ne '10' ]; then
      err0=1
   else
      cycle=t`echo $CDATE10|cut -c9-10`z
      err0=0
   fi
fi

if test $err0 -ne 0
then
#  problem with obtaining date record so exit
   set +x
   echo
   echo "problem with obtaining date record;"
   echo "ABNORMAL EXIT!!!!!!!!!!!"
   echo
   set -x
   $DATA/err_exit
   exit 55  # for extra measure
fi

cyc=`echo $CDATE10|cut -c9-10`
modhr=`expr $cyc % 3`

set +x
echo
echo "CENTER DATE/TIME FOR PREPBUFR PROCESSING IS $CDATE10"
echo
set -x

#----------------------------------------------------------------------------

#  Create variables needed for this script and its children
#  --------------------------------------------------------

envir=${envir:-prod}

envir_getges=${envir_getges:-$envir}
if [ $modhr -eq 0 -o "$NEMSIO_IN" = .true. ]; then
   network_getges=${network_getges:-global}
else
   network_getges=${network_getges:-gfs}
fi

pgmout=${pgmout:-/dev/null}

tstsp=${tstsp:-/tmp/null/}
tmmark=${tmmark:-tm00}

BUFRLIST=${BUFRLIST:-"adpupa proflr aircar aircft satwnd adpsfc sfcshp \
 sfcbog vadwnd goesnd spssmi erscat qkswnd msonet gpsipw rassda wdsatr \
 ascatw"}

PREPDATA=${PREPDATA:-YES}

if [ "$PREPDATA" != 'YES' ] ; then
   POE=NO
   BACK=NO
else
   set +u
   [ -z "$POE" -a "$BACK" = 'YES' ]  &&  POE=NO
   POE=${POE:-YES}
   if [ "$POE" != 'NO' -a "$BACK" = 'YES' ]; then
   set -u
      set +x
echo
echo "YOU have set both POE and BACK to YES - choose one or the other!!"
echo "Defaults are POE=YES and BACK=NO, as is preferable for WCOSS."
echo
      set -x
      exit 99
   fi
   BACK=${BACK:-NO}
   PARALLEL=NO
   [ "$POE" != 'NO' -o "$BACK" = 'YES' ]  &&  PARALLEL=YES
   if [ "$POE" != 'NO' ] ; then
      if [ "$sys_tp" = Cray-XC40 -o "$SITE" = SURGE -o "$SITE" = LUNA ]; then
        launcher_PREP=${launcher_PREP:-aprun}
      else
        launcher_PREP=${launcher_PREP:-mpirun.lsf}
      fi
      if [ "$launcher_PREP" != 'cfp' -a "$launcher_PREP" != aprun ]; then 
         if [ -n ${LSB_HOSTS:-""} ]; then
            NPROCS=$(echo $LSB_HOSTS|wc -w)
            set +x; echo "Setting NPROCS based on LSB_HOSTS count"; set -x
         else
            NPROCS=${NPROCS:-$NSPLIT}
         fi
         if [ $NPROCS -lt $NSPLIT ]; then 
            set +x
echo "********************************************************************"
echo "                   P  R  O  B  L  E  M   !   !   !                  "
echo "********************************************************************"
echo "        NPROCS=$NPROCS IS NOT SUFFICIENT FOR NSPLIT=$NSPLIT         "     
echo "        NPROCS must be greater than NSPLIT when using a             "     
echo "          parallel processing launcher other than cfp               "     
echo "********************************************************************"
            set -x
            msg="***FATAL ERROR:  Insufficient NPROCS for NSPLIT=$NSPLIT"
            [ -n "$jlogfile" ] && $DATA/postmsg "$jlogfile" "$msg"
            $DATA/err_exit
            exit 55  # for extra measure
         fi
      fi
   elif [ "$BACK" = 'YES' ] ; then
      NPROCS=$NSPLIT
   fi
# fi for PREPDATA != YES
fi

USHSYND=${USHSYND:-${HOMEobsproc_prep}/ush}
USHPREV=${USHPREV:-${HOMEobsproc_prep}/ush}
USHCQC=${USHCQC:-${HOMEobsproc_prep}/ush}
USHPQC=${USHPQC:-${HOMEobsproc_prep}/ush}
USHVQC=${USHVQC:-${HOMEobsproc_prep}/ush}
USHAQC=${USHAQC:-${HOMEobsproc_prep}/ush}
USHOIQC=${USHOIQC:-${HOMEobsproc_prep}/ush}

EXECPREP=${EXECPREP:-${HOMEobsproc_prep}/exec}
PARMPREP=${PARMPREP:-${HOMEobsproc_network}/parm}
FIXPREP=${FIXPREP:-${HOMEobsproc_prep}/fix}
DICTPREP=${DICTPREP:-${NWROOTp1}/decoders/decod_shared/dictionaries}

EXECSYND=${EXECSYND:-${HOMEobsproc_prep}/exec}
PARMSYND=${PARMSYND:-${HOMEobsproc_network}/parm}
FIXSYND=${FIXSYND:-${HOMEobsproc_prep}/fix}

GETGUESS=${GETGUESS:-YES}
if [ "$GETGUESS" = 'YES' ]; then
   USHGETGES=${USHGETGES:-${HOMEobsproc_prep}/ush}
   if [ "$NEMSIO_IN" = .true. ]; then
      GETGESprep=${GETGESprep:-$USHGETGES/getges.sh}
   else
      GETGESprep=${GETGESprep:-$USHGETGES/getges_sig.sh}
   fi
fi

PREPDATA=${PREPDATA:-YES}

SYNDATA=${SYNDATA:-YES}

DO_QC=${DO_QC:-YES}

PREVENTS=${PREVENTS:-NO}
CQCBUFR=${CQCBUFR:-YES}
PROFCQC=${PROFCQC:-YES}
CQCVAD=${CQCVAD:-YES}
PREPACQC=${PREPACQC:-YES}
PROCESS_ACQC=${PROCESS_ACQC:-YES}
PROCESS_ACPF=${PROCESS_ACPF:-YES}
OIQCBUFR=${OIQCBUFR:-YES}

MPCOPYX=${MPCOPYX:-$EXECPREP/prepobs_mpcopybufr}
PRPX=${PRPX:-$EXECPREP/prepobs_prepdata}
errPREPDATA_limit=${errPREPDATA_limit:-0}
PRPC=${PRPC:-$PARMPREP/prepobs_prepdata.${NET}.parm}
PRPT=${PRPT:-$FIXPREP/prepobs_prep.bufrtable}
cp $PRPT prep.bufrtable
LANDC=${LANDC:-$FIXPREP/prepobs_landc}
if [ "$NET" = 'gdas' -o "$NET" = 'gfs' ]; then
   PRVT=${PRVT:-$HOMEobsproc_network/fix/prepobs_errtable.global}
elif [ "$NET" = 'cdas' ]; then
   PRVT=${PRVT:-$HOMEobsproc_network/fix/prepobs_errtable.cdas}
elif [ "$NET" = 'nam' ]; then
   PRVT=${PRVT:-$HOMEobsproc_network/fix/prepobs_errtable.nam}
else
   cp /dev/null $DATA/scratch.PRVT
   PRVT=${PRVT:-$DATA/scratch.PRVT}
fi
LISTHDX=${LISTHDX:-$EXECPREP/prepobs_listheaders}
MONOBFRX=${MONOBFRX:-$EXECPREP/prepobs_monoprepbufr}
SYNDX=${SYNDX:-$EXECSYND/syndat_syndata}
SYNDC=${SYNDC:-$PARMSYND/syndat_syndata.${NET}.parm}
PREX=${PREX:-$EXECPREP/prepobs_prevents}
PREC=${PREC:-$PARMPREP/prepobs_prevents.${NET}.parm}
AQCX=${AQCX:-$EXECPREP/prepobs_prepacqc}
AQCC=${AQCC:-$PARMPREP/prepobs_prepacqc.${NET}.parm}
APFX=${APFX:-$EXECPREP/prepobs_prepacpf}
DICT=${DICT:-$DICTPREP/metar.tbl}
PQCX=${PQCX:-$EXECPREP/prepobs_profcqc}
PQCC=${PQCC:-$PARMPREP/prepobs_profcqc.${NET}.parm}
VQCX=${VQCX:-$EXECPREP/prepobs_cqcvad}
CQCX=${CQCX:-$EXECPREP/prepobs_cqcbufr}
CQCC=${CQCC:-$PARMPREP/prepobs_cqcbufr.${NET}.parm}
CQCS=${CQCS:-$FIXPREP/prepobs_cqc_statbge}
OIQCX=${OIQCX:-$EXECPREP/prepobs_oiqcbufr}
if [ "$NET" = 'cdas' ]; then
   OIQCT=${OIQCT:-$HOMEobsproc_network/fix/prepobs_oiqc.oberrs.cdas}
else
   OIQCT=${OIQCT:-$HOMEobsproc_network/fix/prepobs_oiqc.oberrs}
fi
TIMEIT=${TIMEIT:-""}
[ -s $DATA/time ] && TIMEIT="$DATA/time -p"


#  See if tropical cyclone relocation previously ran for this network and cycle
#   by checking for status file in first in $tstsp, and if not found there,
#   then in $COMSP
#  ----------------------------------------------------------------------------

relo_rec=no  # this will remain no even if relocation run, in the event it did
             #  not process an tropical cyclone records
if [ -s ${tstsp}tropcy_relocation_status.$tmmark ]; then
   RELOCATION_HAS_RUN=YES
   msg="Tropical cyclone RELOCATION RAN prior to this job - \
`cat ${tstsp}tropcy_relocation_status.$tmmark`"
   [ "`cat ${tstsp}tropcy_relocation_status.$tmmark`" = "RECORDS PROCESSED" ]  \
    && relo_rec=yes
elif [ -s ${COMSP}tropcy_relocation_status.$tmmark ]; then
   RELOCATION_HAS_RUN=YES
   msg="Tropical cyclone RELOCATION RAN prior to this job - \
`cat ${COMSP}tropcy_relocation_status.$tmmark`"
   [ "`cat ${COMSP}tropcy_relocation_status.$tmmark`" = "RECORDS PROCESSED" ]  \
    && relo_rec=yes
else
   RELOCATION_HAS_RUN=NO
   msg="Tropical cyclone RELOCATION did NOT run prior to this job"
fi
[ -n "$jlogfile" ] && $DATA/postmsg "$jlogfile" "$msg"

if [ -s ${COMSP}tropcy_relocation_status.$tmmark ]; then
   if [ "$SENDDBN" = "YES" ]; then
      if [ "$NET" = 'gfs' -o "$NET" = 'gdas' ]; then
         RUN_uc=$(echo $RUN | tr [a-z] [A-Z])
         $DBNROOT/bin/dbn_alert MODEL ${RUN_uc}_TCI $job \
             ${COMSP}tropcy_relocation_status.$tmmark
      fi
   fi
fi

if [ "$RELOCATION_HAS_RUN" != 'YES' -a "$GETGUESS" != 'NO' ]; then

   if [ $cyc = 00 -o $cyc = 06 -o $cyc = 12 -o $cyc = 18 ]; then

# The GFS and GDAS networks at 00, 06, 12 and 18z will get the t-3 and t+3
#  atmos guess files here since they are needed by the GSI even if tropical
#  cyclone relocation was not previously performed (RELOCATION_HAS_RUN=NO)
#   (NOTE 1: Normally RELOCATION_HAS_RUN=YES for these networks)
#   (NOTE 2: If RELOCATION_HAS_RUN=YES, the t-3 and t+3 atmos guess files have
#            already been obtained for all networks including the GFS and GDAS)
#   (NOTE 3: This is not done if GETGUESS is NO)
#

   if [ "$NET" = 'gfs' -o "$NET" = 'gdas' ]; then
      for fhr in -3 +3 ;do
         if [ "$NEMSIO_IN" = .true. ]; then 
           if [ $fhr = "-3" ] ; then
              sges=sgm3prep
              stype=natgm3
              echo $sges
           else
              sges=sgp3prep
              stype=natgp3
              echo $sges
           fi
         else
           if [ $fhr = "-3" ] ; then
              sges=sgm3prep
              stype=siggm3
              echo $sges
           else
              sges=sgp3prep
              stype=siggp3
              echo $sges
           fi
         fi
         if [ ! -s $sges ]; then
            set +x
            echo
echo "VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV"
echo "           Tropical cylone relocation HAS NOT previously run"
echo "     Get global atmospheric GUESS valid for $fhr hrs relative to center"
echo "                     PREPBUFR processing date/time"
echo "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
            echo
            set -x
            $GETGESprep -e $envir_getges -n $network_getges \
             -v $CDATE10 -t $stype $sges
            errges=$?
            if test $errges -ne 0; then
#  problem obtaining global atmospheric first guess so exit
               set +x
               echo
               echo "problem obtaining global atmos guess valid $fhr hrs \
relative to center PREPBUFR date/time;"
               echo "ABNORMAL EXIT!!!!!!!!!!!"
               echo
               set -x
               $DATA/err_exit
               exit 55  # for extra measure
            fi
            set +x
            echo
echo "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
            echo
            set -x
         fi
      done
   fi
   fi

elif [ "$RELOCATION_HAS_RUN" = 'YES' ]; then

#  If Tropical cyclone relocation previously ran for this network and cycle
#   copy the t-3, t+0 and t+3 atmos guess files and the tcvitals_relocate file
#   from either $tstsp or, if not found there, $COMSP to working directory
#   (Note: tcvitals_relocate file can be empty, but it must exist)
#  --------------------------------------------------------------------------

   qual_last=".$tmmark"  # need this because gfs and gdas don't add $tmmark
                         #  qualifier to end of output atmos guess files
   [ $NET = gfs -o $NET = gdas ]  &&  qual_last=""
   for file in sgm3prep sgesprep sgp3prep tcvitals.relocate.$tmmark; do
      case $file in
        tcvitals.relocate.$tmmark) infile=$file; qual_last="";; #  already has $tmmark at end
        sgm3prep) if [ "$NEMSIO_IN" = .true. ];then infile=atmgm3.nemsio;else infile=$file;fi;;
        sgesprep) if [ "$NEMSIO_IN" = .true. ];then infile=atmges.nemsio;else infile=$file;fi;;
        sgp3prep) if [ "$NEMSIO_IN" = .true. ];then infile=atmgp3.nemsio;else infile=$file;fi;;
      esac
      if [ -s ${tstsp}${infile}${qual_last} ]; then
         cp ${tstsp}${infile}${qual_last} $file
         continue
      elif [ -s ${COMSP}${infile}${qual_last} ]; then
         cp ${COMSP}${infile}${qual_last} $file
         continue
      else
         if [ $file = tcvitals.relocate.$tmmark ]; then
            if [ -f ${tstsp}$file ]; then
               > $file
               continue
            elif [ -f ${COMSP}$file ]; then
               > $file
               continue
            fi
         fi
      fi
#  either t-3,t+0 or t+3 atmos guess file or the tcvitals_relocate file not
#   found in expected location so exit
      set +x
      echo
      echo "$file file not found in expected location where it should have \
populated by earlier tropical cyclone relocation processing"
      echo "ABNORMAL EXIT!!!!!!!!!!!"
      echo
      set -x
      $DATA/err_exit
      exit 55  # for extra measure
   done
   cp tcvitals.relocate.$tmmark tcvitals
   if [ $relo_rec = yes ]; then  # come here if relocation ran and processed
                                 #  1 or more records, means it updated
                                 #  sgesprep
      set +x
      echo
echo "VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV"
echo "     Center PREPBUFR processing date/time is a multiple of 3-hrs"
echo "        Global atmospheric GUESS valid for  0 hrs relative to center"
echo "             PREPBUFR processing date/time was generated by"
echo "             previous tropical cyclone relocation processing"
echo "    It will be encoded into PREPBUFR file and used by q.c. programs"
echo "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
      echo
      set -x
   else                         # come here if relocation ran but did not
                                #  process any records, means it did not update
                                #  sgesprep (sgesprep obtained via getges used)
      set +x
      echo
echo "VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV"
echo "     Center PREPBUFR processing date/time is a multiple of 3-hrs"
echo "        Global atmospheric GUESS valid for  0 hrs relative to center"
echo "         PREPBUFR processing date/time was obtained via GETGES"
echo "    It will be encoded into PREPBUFR file and used by q.c. programs"
echo "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
      echo
      set -x
   fi

fi

###############################################################################
# POSSIBLY OBTAIN GBL ATMOS GUESS FILE(S) FOR LATER ENCODING INTO PREPBUFR FILE
###############################################################################

if [ "$PREPDATA" = 'YES' -o "$SYNDATA" = 'YES' -o "$PREVENTS" = 'YES' ]; then

   SGES=/dev/null
   SGESA=/dev/null
   > sgesprep_pathname
   > sgesprepA_pathname

   if [ "$GETGUESS" != 'NO' ]; then

#  Either ...
#    If the global background guess will be nemsio-based -OR- if the global
#    background guess will be sigio-based and the center PREPBUFR processing
#    date/time is a multiple of 3-hrs, then get a global atmospheric guess valid
#    at the center PREPBUFR processing date/time - this will be interpolated to
#    observation locations by PREPDATA and encoded into the PREPBUFR file for
#    use by the q.c. programs; if a non-zero length file sgesprep exists in the
#    working directory, then this guess is used - otherwise: the GETGES utility
#    is executed to obtain the global atmospheric guess file here
#
#    (NOTE 1: a pre-existing sgesprep file in the working directory at this
#             point was either:
#                copied there prior to the execution of this script
#                    or
#                copied there earlier in this script from either $tstsp, or if
#                  not found there, $COMSP which was populated by the previous
#                  running of tropical cyclone relocation processing
#    (NOTE 2: If imported variable GETGUESS=NO, then bypass this step - a
#             global atmos guess valid at center PREPBUFR time is not obtained)
#
#                   -- or --
#
#       (AND THIS APPLIES ONLY TO A GLOBAL SIGIO-BASED GUESS!!)
#
#    If center PREPBUFR processing date/time is not a multiple of 3-hrs -AND-
#    global guess is sigio-based, then get a global sigma guess valid at the
#    nearest cycle time prior to the center PREPBUFR processing date/time which
#    is a multiple of 3, then get a global sigma guess valid at the nearest
#    cycle time after the center PREPBUFR processing date/time which is a
#    multiple of 3 - the spectral coefficients will be linearly interpolated to
#    the center PREPBUFR processing date/time by the program PREPOBS_PREPDATA
#    and this guess will then be interpolated to observation locations (again by
#    the program PREPOBS_PREPDATA) and encoded into the PREPBUFR file for use by
#    the q.c. programs; if a non-zero length file sgesprep exists in the working
#    directory, then this guess is used for time prior to the center PREPBUFR
#    processing date/time  - otherwise: the utility ush GETGES is executed to
#    obtain the global atmos guess file here (will always be from GFS network);
#
#    likewise if a non-zero length file sgesprepA exists in the working
#    directory, then this guess is used for time after the center PREPBUFR
#    processing date/time - otherwise: the utility ush GETGES is executed to
#    obtain the global atmos guess file here (will always be from the GFS
#    network and initiate at the same time as the guess file valid prior to the
#    PREPBUFR processing date/time)
#
#    (NOTE 1: a pre-existing sgesprep file in the working directory at this
#             point was either:
#                copied there prior to the execution of this script
#                    or
#                copied there earlier in this script from either $tstsp, or if
#                  not found there, $COMSP which was populated by the previous
#                  running of tropical cyclone relocation processing
#    (NOTE 2: a pre-existing sgesprepA file in the working directory at this
#             point was copied there prior to the execution of this script -
#             it could not have been copied from either $tstsp or $COMSP
#             because previous tropical cyclone relocation processing can run
#             only when the center tropical cyclone relocation (or PREPBUFR)
#             processing date/time is a multiple of 3)
#    (NOTE 3: this case is necessary because the gblevents subroutine used to
#             add background forecast values to the prepbufr file expects sigio-
#             based files to be valid only at hours that are a multiple of 3)
#    (NOTE 4: if imported variable GETGUESS=NO, then bypass this step - a
#             global atmos guess valid at center PREPBUFR time is not obtained)
#  ----------------------------------------------------------------------

      for sfx in "" A; do
         if [ ! -s sgesprep${sfx} ]; then
            fhr=any
            if [ "$NEMSIO_IN" = .true. ]; then 
               dhr=0
               stype=natges
            else
               dhr=`expr 0 - $modhr`
               stype=sigges
            fi
            if [ $modhr -eq 0 -o "$NEMSIO_IN" = .true. ]; then
               [ "$sfx" = 'A' ]  &&  break
               set +x
               echo
echo "VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV"
echo "  Either center PREPBUFR processing date/time is a multiple of 3-hrs"
echo "                                -OR-"
echo "                     global guess is nemsio-based"
echo "   Use GETGES to get global sigio-based or nemsio-based GUESS valid for"
echo "             0 hrs relative to center PREPBUFR processing date/time"
echo "     Will be encoded into PREPBUFR file and used by q.c. programs"
echo "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
               echo
               set -x
            else
               if [ "$sfx" = 'A' ]; then
                 typeset -Z2 fhr
                 fhr=`awk -F"sf" '{print$2}' sgesprep_pathname | cut -c1-2`
                 fhr=`expr $fhr + 03`
                 dhr=`expr 3 - $modhr`
               fi
               set +x
               echo
echo "VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV"
echo "   Center PREPBUFR processing date/time is not a multiple of 3-hrs"
               if [ "$sfx" != 'A' ]; then
echo "   Get global atmos GUESS valid at the nearest cycle time prior to"
               else
echo "     Get global atmos GUESS valid at the nearest cycle time after"
               fi
echo "    center PREPBUFR processing date/time which is a multiple of 3"
echo "     Will be used to generate an interpolated guess which will be"
echo "          encoded into PREPBUFR file and used by q.c. programs"
echo "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
               echo
               set -x
            fi
            $GETGESprep -e $envir_getges -n $network_getges -t $stype\
             -f $fhr -v `${NDATE} $dhr $CDATE10` > sgesprep${sfx}_pathname
            errges=$?
            if test $errges -ne 0
            then
#  problem obtaining global sigio-based or nemsio-based guess - exit if center
#   PREPBUFR processing date/time is a multiple of 3-hrs or if global guess is
#   nemsio-based, otherwise continue running but set GETGUESS=NO meaning a
#   first guess will NOT be encoded in PREPBUFR file
               if [ $modhr -eq 0  -o "$NEMSIO_IN" = .true. ]; then
                  if [ "$NEMSIO_IN" = .true. ]; then
                     set +x
                     echo
echo "problem obtaining global nemsio-based guess;"
                  else
                     set +x
                     echo
echo "problem obtaining global sigio-based guess valid  0 hrs relative to \
center PREPBUFR date/time;"
                  fi
echo "ABNORMAL EXIT!!!!!!!!!!!"
                  echo
                  set -x
                  $DATA/err_exit
                  exit 55  # for extra measure
               else
                  set +x
                  echo
echo "problem obtaining global atmos guess valid at the nearest cycle time "
                  if [ "$sfx" != 'A' ]; then
echo "prior to center PREPBUFR processing date/time which is a multiple of 3"
                  else
echo "after center PREPBUFR processing date/time which is a multiple of 3"
                  fi
echo "will continue running but a GUESS will NOT be encoded in PREPBUFR file!!"
                  echo
                  set -x
                  msg="PROBLEM OBTAINING ONE OR BOTH SPANNING ATMOS GUESS \
FILES, GUESS NOT ENCODED IN PREPBUFR FILE  --> non-fatal"
                  [ -n "$jlogfile" ] && $DATA/postmsg "$jlogfile" "$msg"
                  GETGUESS=NO
                  SGES=/dev/null
                  SGESA=/dev/null
                  > sgesprep
                  > sgesprepA
                  > sgesprep_pathname
                  > sgesprepA_pathname
                  break
               fi
            fi
            cp `cat sgesprep${sfx}_pathname | awk '{ print $1 }'` sgesprep${sfx}
            set +x
            echo
echo "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
            echo
            set -x
         else
            if [ $RELOCATION_HAS_RUN = YES ]; then

#  If relocation ran, then ${sfx} is always "" (null) because relocation will
#   only run on center times that are a multiple of 3-hrs - come here to
#   store the pathname for the sgesprep file in sgesprep${sfx}_pathname -
#   note that it will not be stored here if relocation did not process any
#   records, i.e., it did not update the guess, because it was already stored
#   in tropcy_relocate.sh (with the getges path)
#  --------------------------------------------------------------------------

               qual_last=".$tmmark"  # need this because gfs and gdas don't add
                                     #  $tmmark qualifer to end of output atmos
                                     #  guess files
               [ $NET = gfs -o $NET = gdas ]  &&  qual_last=""
               if [ "$NEMSIO_IN" = .true. ]; then 
                  gesbase="atmges.nemsio"
                else
                  gesbase="sgesprep"
               fi
               if [ -s ${tstsp}${gesbase}${qual_last} ]; then
                 echo "${tstsp}${gesbase}${qual_last}" > sgesprep${sfx}_pathname
               elif [ -s ${COMSP}${gesbase}${qual_last} ]; then
                 echo "${COMSP}${gesbase}${qual_last}" > sgesprep${sfx}_pathname
               fi
            else

#  If relocation did not run, then the guess files in $DATA were copied there
#   prior to the execution of this script by the user - just echo the path
#   to this guess file in $DATA into sgesprep${sfx}_pathname
#  --------------------------------------------------------------------------

               echo "$DATA/sgesprep${sfx}" > sgesprep${sfx}_pathname
            fi
         fi
         eval SGES${sfx}=$DATA/sgesprep${sfx}
      done
   fi
fi

################################
#  EXECUTE PREPDATA PROCESSING
################################

if [ "$PREPDATA" = 'YES' ]; then

   cd $DATA 

set +u
   if [ -z "$PREPBUFR_APP" -o "$PARALLEL" = 'YES' ]; then
set -u
      if [ ! -s ${tstsp}status.${tmmark}.bufr_d -a \
           ! -s ${COMSP}status.${tmmark}.bufr_d ]; then

#########if [ \( ! -s ${tstsp}status1.${tmmark}.bufr_d -o \
#########        ! -s ${tstsp}status2.${tmmark}.bufr_d \) -a \
#########     \( ! -s ${COMSP}status1.${tmmark}.bufr_d -o \
#########        ! -s ${COMSP}status2.${tmmark}.bufr_d \) ]; then
         if [ ! -s ${tstsp}status1.${tmmark}.bufr_d -a \
              ! -s ${COMSP}status1.${tmmark}.bufr_d ]; then

#  problem: status file not found - indicates some or all data dumps were not
#           found (produced) for requested time ...
#           If highest level directory pointing to input BUFR observational
#            data dumps is /com or /com2 then EXIT (assumes all data dumps are
#            required)
#           Otherwise, just echo a diagnostic (assumes only some data dumps are
#           required)
#  ----------------------------------------------------------------------------

echo
echo "Some or all BUFR data dumps were not found for requested time ... "
echo
            set -x

            if [[ "$COMSP" =~ (^/com/|^/com2/|^/gpfs/.../nco/ops/com/) && \
                "$tstsp" =~ (^/tmp/null)  ]]; then
               set +x
echo
echo "ABNORMAL EXIT!!!!!!!!!!!"
echo
               set -x
               $DATA/err_exit
               exit 55  # for extra measure
            fi
         fi
      fi

      echo $BUFRLIST | grep adpsfc
      grp_adpsfc=$?
      echo $BUFRLIST | grep adpupa
      grp_adpupa=$?
      if [ \( ! -f ${COMSP}adpsfc.${tmmark}.bufr_d -a \
              ! -f ${tstsp}adpsfc.${tmmark}.bufr_d -a $grp_adpsfc -eq 0 \) -o \
           \( ! -f ${COMSP}adpupa.${tmmark}.bufr_d -a \
              ! -f ${tstsp}adpupa.${tmmark}.bufr_d -a $grp_adpupa -eq 0 \) ]
      then

#  problem: either adpsfc (surface land) or adpupa (raob/pibal/recco) file, or
#           both, not found for requested time - this is unacceptable; EXIT
#           (unless the culprit file was not included in the $BUFRLIST)
#  ---------------------------------------------------------------------------

         set +x
echo
echo "ADPSFC and/or ADPUPA BUFR data dump was not produced for requested"
echo " time (but is in BUFRLIST); ABNORMAL EXIT!!!!!!!!!!!"
echo
         set -x
         $DATA/err_exit
         exit 55  # for extra measure
      fi

   fi

   for name in ${BUFRLIST} ;do
      > $name
      if [ -f ${tstsp}${name}.${tmmark}.bufr_d ]; then
         cp ${tstsp}${name}.${tmmark}.bufr_d $name
      elif [ -s ${COMSP}${name}.${tmmark}.bufr_d ]; then
         cp ${COMSP}${name}.${tmmark}.bufr_d $name
      fi
   done

   > prep_exec.cmd

   > prepda.${cycle}

   echo "      $CDATE10" > cdate10.dat

# If GETGUESS=YES, then either ...
#   a global sigio-based guess file valid at the center PREPBUFR processing
#   date/time which is a multiple of 3-hrs is valid at this point
#                                 -- or --
#   global sigio-based guess files valid at times which are multiples of 3-hrs
#   and span the center PREPBUFR processing date/time which is NOT a multiple of
#   3-hrs are available and valid at this point
#                                 -- or --
#   a global nemsio-based guess file valid at the center PREPBUFR processing
#   date/time for any hour is valid at this point

#  In any case, namelist "GBLEVN" with PREVEN=T is cat'ed to the beginning
#  of the PREPOBS_PREPDATA program data cards file - this means
#  PREPOBS_PREPDATA will call w3emc routine GBLEVENTS to do the "prevents"
#  processing (otherwise PREVEN=F by default)

   > prepdata.stdin
   [ "$GETGUESS" != 'NO' ] && echo " &gblevn preven=true /" >>prepdata.stdin
   cat $PRPC >> prepdata.stdin

# Check contents of *aircar_status_flag* file in $tstsp, or if not found there,
#  $COMSP path - this was generated by previous bufr_dump_obs.sh script: if it
#  exists and indicates that there were more AFWA (backup) ACARS reports than
#  ARINC (primary) ACARS reports in the AIRCAR dump, then skip processing of
#  ARINC ACARS messages in PREPOBS_PREPDATA (meaning process ONLY AFWA ACARS
#  messages); otherwise, as is usually the case, skip processing of AFWA ACARS
#  messages (meaning process only ARINC ACARS messages in PREPOBS_PREPDATA)

   echo "   SUBSKP(004,007) = TRUE," > insert
   if [ -s ${tstsp}aircar_status_flag.${tmmark}.bufr_d ]; then
      grep -q -Fe "004.007" ${tstsp}aircar_status_flag.${tmmark}.bufr_d
      err_grep=$?
      if [ $err_grep -eq 0 ]; then
         echo "   SUBSKP(004,004) = TRUE," > insert
         msg="***WARNING: Dump count for ARINC ACARS < AFWA ACARS; encode \
backup AFWA ACARS into PREPBUFR"
         [ -n "$jlogfile" ] && $DATA/postmsg "$jlogfile" "$msg"
      fi
   elif [ -s ${COMSP}aircar_status_flag.${tmmark}.bufr_d ]; then
      grep -q -Fe "004.007" ${COMSP}aircar_status_flag.${tmmark}.bufr_d
      err_grep=$?
      if [ $err_grep -eq 0 ]; then
         echo "   SUBSKP(004,004) = TRUE," > insert
         msg="***WARNING: Dump count for ARINC ACARS < AFWA ACARS; encode \
backup AFWA ACARS into PREPBUFR"
         [ -n "$jlogfile" ] && $DATA/postmsg "$jlogfile" "$msg"
      fi
   fi

   grep -q -Fe "`cat insert`" prepdata.stdin
   err_grep=$?
   if [ $err_grep -ne 0 ]; then
      nlines=`cat < prepdata.stdin | wc -l`
      line=`grep -n -Fe "&LDTA" prepdata.stdin | cut -f1 -d:`
      head -n $line prepdata.stdin > top_part
      mlines=`expr $nlines - $line`
      tail -n $mlines prepdata.stdin > bottom_part
      [ $mlines -gt 2 ] && cat top_part insert bottom_part > prepdata.stdin
      rm top_part bottom_part
   fi
   rm insert


##VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV##
##                          HEREFILE MP_PREPDATA                             ##
##VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV##

set +x
cat <<\EOFmpp > MP_PREPDATA

{ echo

# This herefile script performs the "prepdata" processing.  It is designed to
#  run in either a parallel (e.g., poe/mpi or background threads) or serial
#  environment. In the parallel environment, it first splits the input BUFR
#  data dump files into $NSPLIT equally-sized parts (analogous to dealing
#  multiple sets of cards to $NSPLIT players, where each set of cards is a
#  different BUFR data dump file). Next, in either the parallel or serial 
#  environment, it runs PREPOBS_PREPDATA to write out prepbufr files (either
#  a single complete file in the serial environment or $NSPLIT partial
#  PREPBUFR files in the parallel environment). Finally, it generates a list of
#  PREPBUFR message headers which, in the parallel environment, is needed to
#  later merge the partial PREPBUFR files together in the proper order.
#
#  IMPORTANT: This script assumes that the BUFR data dump files it is to
#             process have been copied into the $DATA directory and that each
#             file name is the same as in $BUFRLIST. It also assumes that the
#             NCEP production date file is present in the $DATA directory and
#             that it is called cdate10.dat.  Finally, it assumes that the
#             PREPOBS_PREPDATA program data cards (parm) file is present in the
#             $DATA directory and it is called prepdata.stdin
# -----------------------------------------------------------------------------
#
# Positional parameters passed in:
#   1 - Stream index ($multi) (0 to $NSPLIT-1)
#
# Imported variables that must be passed in:
#   DATA     - path to working directory
#   PARALLEL - indicates whether or not this script is running in a parallel
#               (e.g., poe/mpi or background threads) or serial environment
#               "YES" - running in a parallel environment; "NO" running in a 
#               serial environment)
#   NSPLIT     number of parts into which the input BUFR data dump files are to
#               be evenly divided (applicable only when PARALLEL is "YES")
#   BUFRLIST - list of BUFR data dump files to process
#   MPCOPYX  - path to PREPOBS_MPCOPYBUFR program executable
#   PRPT     - path to PREPOBS_PREPDATA bufrtable file
#   LANDC    - path to land/sea mask file
#   SGES     - path to COPY OF global sigio-based or nemsio-based first guess
#               file valid at either center PREPBUFR processing date/time or,
#               for global sigio-based guess only, nearest 3-hrly cycle time
#               prior to center PREPBUFR processing date/time
#   SGESA    - path to COPY OF global sigio-based guess file valid at nearest
#               3-hrly cycle AFTER center PREPBUFR processing date/time (if
#               needed, otherwise /dev/null). Only used if SGES is valid at
#               3-hrly cycle time PRIOR to center PREPBUFR processing date/time
#               (and thus not used if NEMSIO_IN=.true.)
#   PRVT     - path to observation error table file
#   PRPX     - path to PREPOBS_PREPDATA program executable
#   LISTHDX  - path to PREPOBS_LISTHEADERS program executable

set -aux
multi=$1

data=$DATA/multi$multi

if [ ! -d $DATA/multi$multi ] ; then
   mkdir -p $DATA/multi$multi
fi

status=$data/mstatus ; > $status 
mp_pgmout=$data/mp_pgmout  ; > $mp_pgmout 


{ echo
set +x
echo
echo "********************************************************************"
echo "This is stream (task/thread) $multi executing on node  `hostname -s`"
echo "Starting time: `date`"
echo "********************************************************************"
echo
set -x
} >> $mp_pgmout

cd $data

if [ "$PARALLEL" = 'YES' ]; then

   n=0

   pgm=`basename  $MPCOPYX`
#-----mimics prep_step-----
   set +x
   echo $pgm > pgmname
   set +u
   [ -z "$mp_pgmout" ] && echo "Variable mp_pgmout not set"
   set -u
   [ -s $DATA/break ] && paste pgmname $DATA/break >> $mp_pgmout
   rm pgmname
   [ -f errfile ] && rm errfile
   unset FORT00 `env | grep "^FORT[0-9]\{1,\}=" | awk -F= '{print $1}'`
   [ -s $DATA/tracer ] && cat $DATA/tracer > errfile
   set -x
#--------------------------

   for name in ${BUFRLIST[*]} ;do
      > $name
      if [ -s $DATA/$name ] ; then
         ((n+=1))
         export FORT$((10+n))=$DATA/$name
         export FORT$((50+n))=$name
      fi
   done

   cat<<EOF|$TIMEIT $MPCOPYX >> $mp_pgmout 2>&1
 &namin nfiles=$n /
 &mp nprocs=$NSPLIT,mp_process=$multi /
EOF
   err=$?
   set +x
   echo
   echo "The foreground exit status for PREPOBS_MPCOPYBUFR is " $err
   echo
   set -x

   [ "$err" -gt '0' ]  && exit

   dump_dir=$data

else

   dump_dir=$DATA

# fi for $PARALLEL = YES
fi


pgm=`basename  $PRPX`
#-----mimics prep_step-----
set +x
echo $pgm > pgmname
set +u
[ -z "$mp_pgmout" ] && echo "Variable mp_pgmout not set"
set -u
[ -s $DATA/break ] && paste pgmname $DATA/break >> $mp_pgmout
rm pgmname
[ -f errfile ] && rm errfile
unset FORT00 `env | grep "^FORT[0-9]\{1,\}=" | awk -F= '{print $1}'`
[ -s $DATA/tracer ] && cat $DATA/tracer > errfile
set -x
#--------------------------

set +u
[ -n "$PREPBUFR_APP" -a "$PARALLEL" = 'NO' ] && \
 cp $PREPBUFR_APP prepda
set -u

#  Namelist "TASK" with mp_process set to the value of $multi - either the poe/
#   mpi task number (for POE not equal to "NO") or to the background thread
#   number (for BACK equal to "YES") in the parallel environment, or hardwired
#   to zero in the serial environment, is cat'ed to the beginning of the
#   PREPOBS_PREPDATA program data cards (parm) file - this will allow
#   PREPOBS_PREPDATA to identify this stream

> prepdata.stdin
echo " &task mp_process=$multi /" >>prepdata.stdin
cat $DATA/prepdata.stdin >> prepdata.stdin

BUFRLIST_all="adpupa aircar aircft satwnd proflr vadwnd rassda adpsfc sfcshp \
 sfcbog msonet spssmi erscat qkswnd wdsatr ascatw rtovs atovs goesnd gpsipw"
###BUFRLIST_all_array=($BUFRLIST_all) # this does not work on all platforms
set -A BUFRLIST_all_array `echo $BUFRLIST_all` # this works on all platforms


# Any dump file not included in BUFRLIST is "touched" so that it will not
#  cause a read error in the event that PREPOBS_PREPDATA still tries to read it

for name in $BUFRLIST_all;do
[ ! -f $dump_dir/$name ]  &&  > $dump_dir/$name
done

export FORT11=$DATA/cdate10.dat
export FORT12=$PRPT
export FORT15=$LANDC
##   export FORT18=$SGES
##   export FORT19=$SGESA

# The PREPOBS_PREPDATA code opens GFS spectral coefficient guess files using 
# sigio routines or GFS gaussian grid guess files using nemsio routines (via
# W3EMC routine GBLEVENTS) in a manner that may not recognize the FORTxx
# variables above.  So, the above statements setting FORTxx vars for $SGES and
# $SGESA are replaced by the soft links below.

ln -sf $SGES              fort.18
ln -sf $SGESA             fort.19
export FORT20=$PRVT
export FORT21=$dump_dir/${BUFRLIST_all_array[0]}
export FORT22=$dump_dir/${BUFRLIST_all_array[1]}
export FORT23=$dump_dir/${BUFRLIST_all_array[2]}
export FORT24=$dump_dir/${BUFRLIST_all_array[3]}
export FORT25=$dump_dir/${BUFRLIST_all_array[4]}
export FORT26=$dump_dir/${BUFRLIST_all_array[5]}
export FORT27=$dump_dir/${BUFRLIST_all_array[6]}
export FORT31=$dump_dir/${BUFRLIST_all_array[7]}
export FORT32=$dump_dir/${BUFRLIST_all_array[8]}
export FORT33=$dump_dir/${BUFRLIST_all_array[9]}
export FORT34=$dump_dir/${BUFRLIST_all_array[10]}
export FORT35=$dump_dir/${BUFRLIST_all_array[11]}
export FORT36=$dump_dir/${BUFRLIST_all_array[12]}
export FORT37=$dump_dir/${BUFRLIST_all_array[13]}
export FORT38=$dump_dir/${BUFRLIST_all_array[14]}
export FORT39=$dump_dir/${BUFRLIST_all_array[15]}
export FORT41=$dump_dir/${BUFRLIST_all_array[16]}
export FORT42=$dump_dir/${BUFRLIST_all_array[17]}
export FORT46=$dump_dir/${BUFRLIST_all_array[18]}
export FORT48=$dump_dir/${BUFRLIST_all_array[19]}
export FORT51=prepda
export FORT52=prevents.filtering.prepdata

#### THE BELOW APPLIED TO THE CCS (IBM AIX)  (kept for reference)
#If program ever fails, try changing 64000000 to 20000000
#set +u
#[ -n "$LOADL_PROCESSOR_LIST" ]  &&  XLSMPOPTS=parthds=2:stack=64000000
#set -u

# The following improves performance on Cray-XC40 if $PRPX was
#    linked to the IOBUF i/o buffering library
export IOBUF_PARAMS='*prevents.filtering.prepdata:verbose'

$TIMEIT $PRPX <prepdata.stdin >>$mp_pgmout 2>&1
errPREPDATA=$?
unset IOBUF_PARAMS
cat prevents.filtering.prepdata >> $mp_pgmout
set +x
echo
echo "The foreground exit status for PREPOBS_PREPDATA is " $errPREPDATA
echo
set -x

[ "$errPREPDATA" -gt '4' -o "$errPREPDATA" -eq '1' ]  && exit

# Will execute PREPOBS_LISTHEADERS even if PARALLEL is "NO", because it will
#  reorder the monolithic PREPBUFR file to ensure that all messages of the same
#  subtype will always be grouped together in sequential messages, arranged in
#  the order found in $PRPT (Note: This is a necessity when PARALLEL is "YES"
#  because the later program PREPOBS_MONOPREPBUFR must merge the $NSPLIT
#  individual (partial) PREPBUFR files together in the proper order)


# Build listhdx.stdin from bufrtable entries of possible message headers first
#  line is count, followed by list

grep "| A[0-9]\{5,\} |" $PRPT | awk '{print $2}'|wc -l|tee listhdx.stdin
grep "| A[0-9]\{5,\} |" $PRPT | awk '{print $2}'|tee -a listhdx.stdin

pgm=`basename  $LISTHDX`
#-----mimics prep_step-----
set +x
echo $pgm > pgmname
set +u
[ -z "$mp_pgmout" ] && echo "Variable mp_pgmout not set"
set -u
[ -s $DATA/break ] && paste pgmname $DATA/break >> $mp_pgmout
rm pgmname
[ -f errfile ] && rm errfile
unset FORT00 `env | grep "^FORT[0-9]\{1,\}=" | awk -F= '{print $1}'`
[ -s $DATA/tracer ] && cat $DATA/tracer > errfile
set -x
#--------------------------

export FORT11=prepda
export FORT51=prepda.reorder
export FORT52=prepda.hdrs

$TIMEIT $LISTHDX < listhdx.stdin >>$mp_pgmout 2>&1
err=$?
cat prepda.hdrs
set +x
echo
echo "The foreground exit status for PREPOBS_LISTHEADERS is " $err
echo
set -x

[ "$err" -gt '0' ]  && exit

mv prepda.reorder prepda
rm listhdx.stdin

echo "$multi finished -- errPREPDATA = $errPREPDATA" > $status 

{ echo
set +x
echo
echo "********************************************************************"
echo "Finished executing on node  `hostname -s`"
echo "Ending time  : `date`"
echo "********************************************************************"
echo
set -x
} >> $mp_pgmout

} 1> $DATA/mp_stream${1}.stdout 2> $DATA/mp_stream${1}.errfile

exit 0
EOFmpp
set -x

##AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA##
##                       end of HEREFILE MP_PREPDATA                         ##
##AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA##

   chmod 775 MP_PREPDATA

   if [ "$PARALLEL" = 'YES' ]; then

#  In the parallel environment, either cat the multiple MP_PREPDATA tasks
#   into a poe command file (for poe/mpi/cfp) - or - set up a script that will
#   fire off each MP_PREPDATA thread as a background process
#  -----------------------------------------------------------------------
      if [ "$POE" != 'NO' ]; then
         multi=-1
         while [ $((multi+=1)) -lt $NSPLIT ] ; do
            echo "ksh $DATA/MP_PREPDATA $multi "|tee -a $DATA/prep_exec.cmd
         done
         if [ "$launcher_PREP" != cfp -a "$launcher_PREP" != aprun ]; then
            # fill in empty tasks
            multi=$((multi-=1))  #need to go back one
            while [ $((multi+=1)) -lt $NPROCS ] ; do
               echo "echo do-nothing" >> $DATA/prep_exec.cmd
            done
         fi
      elif [ $BACK = 'YES' ] ; then
         multi=-1
         echo "#!/bin/ksh" > $DATA/prepthrds.sh
         while [ $((multi+=1)) -lt $NSPLIT ] ; do
            echo "$DATA/MP_PREPDATA $multi &" >> $DATA/prepthrds.sh
            echo "echo $DATA/MP_PREPDATA $multi submitted in background" \
                                                           >> $DATA/prepthrds.sh
         done
         echo "wait" >> $DATA/prepthrds.sh
         chmod 775 $DATA/prepthrds.sh
      fi

#  In the parallel environment, next either execute the poe wrapper (for poe/
#   mpi/cfp) (do not execute a time command with poe!) - or - run prepthrds.sh
#   to kick off background processes and wait for them to complete
#  --------------------------------------------------------------------------
      if [ "$POE" != 'NO' ]; then
         if [ "$launcher_PREP" = mpirun.lsf ]; then
            export MP_CMDFILE=$DATA/prep_exec.cmd
            export MP_PGMMODEL=mpmd
            export MP_PULSE=0
            export MP_DEBUG_NOTIMEOUT=yes
            export MP_LABELIO=yes
            export MP_STDOUTMODE=ordered
            mpirun.lsf
            export err=$?; $DATA/err_chk
            [ $err != 0 ] && exit 55  # for extra measure
         elif [ "$launcher_PREP" = cfp ]; then
            export MP_CSS_INTERRUPT=yes
            export MP_LABELIO=yes
            export MP_STDOUTMODE=ordered
            mpirun.lsf cfp $DATA/prep_exec.cmd
            export err=$?; $DATA/err_chk
            [ $err != 0 ] && exit 55  # for extra measure
         elif [ "$launcher_PREP" = aprun ]; then
            ## Determine tasks per node (PREPDATAtpn) and
            ##    max number of concurrent procs (PREPDATAprocs) for cfp
            typeset -i nodesall=$(echo -e "${LSB_HOSTS// /\\n}"|sort -u|wc -w)
            typeset -i ncnodes=$(($nodesall-1)) # we want compute nodes only
            if [ $ncnodes -lt 1 ]; then
               set +x
               echo
               echo " ** Could not get positive compute node count for aprun **"
               echo " ** Are we using LSF queue with compute node access? **"
               echo
               echo "ABNORMAL EXIT!!!!!!!!!!!"
               echo
               set -x
               $DATA/err_exit
               exit 55  # for extra measure
            fi
            if [[ -z ${PREPDATAtpn:-""} ]]; then
               PREPDATAtpn=$((($NSPLIT+$ncnodes-1)/$ncnodes))
               # cfp is faster with extra thread so add one if there is room.
               #  (this logic needs an update to avoid hardwired 24)
               [ $PREPDATAtpn -lt 24 ] && PREPDATAtpn=$(($PREPDATAtpn+1))
            fi
            if [[ -z ${PREPDATAprocs:-""} ]]; then
              PREPDATAprocs=$(($ncnodes*$PREPDATAtpn))  # max concurrent processes
            fi
            aprun -j 1 -n${PREPDATAprocs} -N${PREPDATAtpn} -d1 cfp $DATA/prep_exec.cmd
            export err=$?; $DATA/err_chk
            [ $err != 0 ] && exit 55  # for extra measure
         else  # unknown launcher and options (eg, for use on R&D system) 
            $launcher_PREP
            export err=$?; $DATA/err_chk
            [ $err != 0 ] && exit 55  # for extra measure
         fi
      elif [ $BACK = 'YES' ] ; then
         if [ "$sys_tp" = Cray-XC40 -o "$SITE" = SURGE -o "$SITE" = LUNA ]; then
            aprun -n 1 -d $NSPLIT $DATA/prepthrds.sh
         else
            $DATA/prepthrds.sh
         fi
      fi
      totalt=$NSPLIT
   else

#  In the serial environment, just fire off a single thread of MP_PREPDATA
#  -----------------------------------------------------------------------
      multi=0
      if [ "$sys_tp" = Cray-XC40 -o "$SITE" = SURGE -o "$SITE" = LUNA ]; then
         aprun -n 1 -N 1 ksh $DATA/MP_PREPDATA $multi
      else
         $DATA/MP_PREPDATA $multi
      fi
      totalt=1

   # fi for $PARALLEL = YES
   fi

   set +x
   multi=0
   while [ $multi -lt $totalt ]; do
echo
echo "********************************************************************"
echo "  ++  Script STDOUT from MP_PREPDATA for stream (task/thread) $multi  ++"
echo "********************************************************************"
echo
      cat $DATA/mp_stream${multi}.stdout
echo "********************************************************************"
echo "  ++  End of Script STDOUT from MP_PREPDATA for stream $multi  ++  "
echo "********************************************************************"
      multi=`expr $multi + 1`
   done

echo
echo "********************************************************************"
echo "  ++  Script trace from MP_PREPDATA for stream (task/thread) 0  ++     "
   if [ "$PARALLEL" = 'YES' ]; then
echo
echo "      In order to conserve space, the script trace from other       "
echo "         streams is not invoked unless the stream failed.           "
   fi
echo "********************************************************************"
echo

   cat mp_stream0.errfile

echo
echo "********************************************************************"
echo "  ++  End of Script trace from MP_PREPDATA for stream  0 ++  "
echo "********************************************************************"
echo
   set -x

#  check status files
#  ------------------

   errSTATUS=0
   errPREPDATA=0
   four_check=yes
   multi=0
   while [ $multi -lt $totalt ]; do
      cat $DATA/multi$multi/mp_pgmout >> prepdata.out
      cat $DATA/multi$multi/mp_pgmout >> $pgmout
      status=$DATA/multi$multi/mstatus
      if [ ! -s $status ]; then
   set +x
echo
echo "********************************************************************"
echo "                   P  R  O  B  L  E  M   !   !   !                  "
echo "********************************************************************"
echo " ###> MP_PREPDATA stream (task/thread) $multi FAILED - Cycle date: \
$CDATE10"
echo "       Current working directory: $DATA                             "
echo
echo "      Script trace from MP_PREPDATA for stream $multi follows ...   "
echo "********************************************************************"
echo
         cat $DATA/mp_stream${multi}.errfile
echo
echo "********************************************************************"
echo "  ++  End of Script trace from MP_PREPDATA for stream $multi ++ "
echo "********************************************************************"
echo
   set -x
         errSTATUS=99
      else
         err_this=`cut -f 2 -d = $status`
         [ "$err_this" -gt "$errPREPDATA" ]  && errPREPDATA=$err_this
         [ "$err_this" -eq '0' ]  && four_check=no
      fi
      multi=`expr $multi + 1`
   done

   if [ "$errSTATUS" -gt '0' ]; then
      $DATA/err_exit
      exit 55  # for extra measure
   fi

   [ "$errPREPDATA" -eq '4' -a "$four_check" = 'no' ]  && errPREPDATA=0

   set +x
   echo
   echo "For all MP_PREPDATA Streams, the largest foreground exit status \
 amongst all PREPOBS_PREPDATA runs is " $errPREPDATA
   echo
   set -x

   if [ "$errPREPDATA" -le "$errPREPDATA_limit" -a $errPREPDATA -ne 1 ]; then
      err=0
      if [ "$errPREPDATA" -eq '4' ]; then
         set +x
         echo
   echo "WARNING: PREPOBS_PREPDATA FOUND EITHER NO ADPUPA OR NO ADPSFC DATA"
   echo "-------- THESE DATA WILL NOT BE AVAILABLE TO ANALYSES"
         echo
         set -x
      fi
   else
      err=$errPREPDATA
   fi

   pgm=`basename  $PRPX`
   touch errfile
   $DATA/err_chk
   [ $err != 0 ] && exit 55  # for extra measure

   if [ "$PARALLEL" = 'YES' ]; then

##VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV##
##                          HEREFILE MERGE_MSGS                              ##
##VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV##

set +x
cat <<\EOFmrg > MERGE_MSGS

# This herefile script merges the individual partial PREPBUFR files present at
#  this point into a complete, monolithic PREPBUFR file in the proper message
#  type order.  It is the last step in the PREPDATA processing.  It runs only
#  in the parallel environment.
# ----------------------------------------------------------------------------

# Positional parameters passed in:
#   1 - Number of input partial PREPBUFR files that are going to be merged
#       ($nfiles)
#   2 - Working directory path ($DATA) (contains separate partial PREPBUFR
#       files and text files containing headers for each, one directory down)
#   3 - Beginning string of sub-directories in $DATA ($subdir) (each sub-
#       directory contains an input partial PREPBUFR file and a text file
#       containing headers for all messages in that PREPBUFR file)
#   4 - File in each sub-directory containing headers for all messages in
#       partial PREPBUFR file in same sub-directory (file name only - same name
#       in all sub-directories) ($header_file_name)
#   5 - Partial PREPBUFR file in each sub-directory (file name only - same name
#       in all sub-directories) ($prep_in)
#   6 - Output monolithic PREPBUFR file name (file name only) ($prep_out)
#
# Imported variables that must be passed in:
#   MONOBFRX - path to PREPOBS_MONOPREPBUFR program executable
#
# Imported variables that can be passed in:
#   pgmout   - string indicating path to for standard output file (skipped over
#              by this script if not passed in)


if [ $# -ne 6 ] ; then
   echo "Usage: $0 nfiles DATA subdir header_file_name prep_in prep_out"
   exit 1
fi

set -aux

qid=$$

nfiles=$1;DATA=$2;subdir=$3;header_file_name=$4;prep_in=$5;prep_out=$6


#  From all the header files, extract the header counts and names build
#   namelist input to drive $MONOBFRX program
#  ---------------------------------------------------------------------

nheaders=`cat $DATA/${subdir}*/$header_file_name|awk '{print $1}'|sort -u|wc -l`
((nheaders+=0))

>$DATA/input echo  
echo " &namin nfiles=$nfiles, nheaders=$nheaders," >>$DATA/input

cd $DATA


#  Assign the fort units to the files
#  -----------------------------------

pgm=`basename  $MONOBFRX`
if [ -s $DATA/prep_step ]; then
   . $DATA/prep_step
else
   [ -f errfile ] && rm errfile
   unset FORT00 `env | grep "^FORT[0-9]\{1,\}=" | awk -F= '{print $1}'`
fi


n=-1
while [ $((n+=1)) -lt $nfiles ] ;do 
   [ ! -s $DATA/${subdir}$n/$prep_in ]  &&  exit 1 
   export FORT$((11+n))=$DATA/${subdir}$n/$prep_in
done
export FORT51=$prep_out
set +x


#  Extract the total span of headers by searching through all the header files
#  ---------------------------------------------------------------------------

n=-1
while [ $((n+=1)) -lt $nfiles ]; do 
   file=$DATA/${subdir}$n/$header_file_name
   [ ! -s $file ]  &&  exit 1 
   if [ `cat $file|awk '{print $1}'| \
    sort -u|wc -l` -eq $nheaders ] ; then
      headers="" 
      nlines=`cat $file|wc -l` 
      i=0
      while [ $((i+=1)) -le $nlines ]; do
         line=`sed -n $i,${i}p $file`
         header=`echo $line|awk '{print $1}'`
         echo " cheaders($i)='$header',">>$DATA/input
         headers="$headers $header"
      done
      break
   fi
done


#  Tranlate the hdrs file contents into namelist array 
#  ---------------------------------------------------

n=-1
while [ $((n+=1)) -lt $nfiles ]; do 
   file=$DATA/${subdir}$n/$header_file_name
   line=
   i=0
   for hdr in $headers; do
      ((i+=1))
      count=`grep $hdr $file|awk '{print $2}'`
      set +u
      [ -z "$count" ]  &&  count=0
      set -u
      line="${line}msgs($i,$((n+1)))=$count," 
   done
   echo " $line " >>$DATA/input
done

echo " &end" >>$DATA/input
set -x
cat $DATA/input

$TIMEIT $MONOBFRX <$DATA/input > outout 2> errfile
export err=$?
###cat errfile
cat errfile >> outout
cat outout >> monoprepbufr.out
set +u
[ -n "$pgmout" ]  &&  cat outout >> $pgmout
set -u
rm outout
set +x
echo
echo "The foreground exit status for PREPOBS_MONOPREPBUFR is " $err
echo
set -x
$DATA/err_chk
[ $err != 0 ] && exit 55  # for extra measure

exit 0
EOFmrg
set -x

##AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA##
##                       end of HEREFILE MERGE_MSGS                          ##
##AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA##

   chmod 775 MERGE_MSGS

#  In parallel environment, make monolithic PREPBUFR file by meriging the
#   partial PREPBUFR files
#  ----------------------------------------------------------------------
      $TIMEIT $DATA/MERGE_MSGS $NSPLIT $DATA multi prepda.hdrs prepda \
       prepda.${cycle}
      errsc=$?
      if test $errsc -ne 0
      then
#  problem with merge script
         $DATA/err_exit
         exit 55  # for extra measure
      fi
   else

#  In serial environment, already have a monolithic PREPBUFR file - just
#   copy it to expected local monolithic PREPBUFR file location
#  ---------------------------------------------------------------------
      cp $DATA/multi0/prepda prepda.${cycle}

   # fi for $PARALLEL = YES
   fi

# fi for $PREPDATA = YES
fi

set +u
[ -n "$PREPBUFR_IN" ]  &&  cp $PREPBUFR_IN $DATA/prepda.${cycle}
set -u


############################################
# EXECUTE SYNTHETIC CYCLONE DATA PROCESSING
############################################

if [ "$SYNDATA"  = 'YES' ]; then

#  Check condition code - SDM can shut-off synthetic cyclone bogusing
#  ------------------------------------------------------------------
# ==> this switch is NOT YET in place, so it will be hardwired to "YES"

###cp ???????????? syndata_cond
   echo "YES" > syndata_cond
   SYN=`cat <syndata_cond|cut -c1-3`
   set +x
   echo
   echo "SYNTHETIC CYCLONE PROCESSING = $SYN"
   echo
   set -x
   if [ "$SYN" = 'YES' ]; then

      DO_BOGUS=YES
      run_syndat_twice=no
      if [ -f ${tstsp}syndata.tcvitals.$tmmark ]; then
         cp ${tstsp}syndata.tcvitals.$tmmark tcvitals_orig
      else
         cp ${COMSP}syndata.tcvitals.$tmmark tcvitals_orig
      fi

      if [ "$RELOCATION_HAS_RUN" != 'YES' -o "$NET" = 'nam' ]; then

# If RELOCATION_HAS_RUN=NO or NET=nam, always use original tcvitals file here
#  to ensure that SYNDATA will run if there are records in the original
#  tcvitals file (for NET=nam, RELOCATION_HAS_RUN may be YES but previous
#  tropical cyclone relocation processing was only used to update the first
#  guess read in by the various PREPBUFR processing programs and it mostly like
#  would have generated a null tcvitals file which would prevent SYNDATA from
#  running)

         cp tcvitals_orig tcvitals
      else
         if [ ! -s tcvitals ]; then

#  If RELOCATION_HAS_RUN=YES, NET is not nam (currently meaning it is gfs or
#   gdas), and the tcvitals file generated by previous tropical cyclone
#   relocation processing is null (which is usually the case) -- still want
#   SYNDATA to run but to NOT append bogus reports - it WILL flag dropwinsonde
#   winds near storms (if requested) but it will NOT flag mass pressure reports
#   near storms (regardless of requested switch)
#  Use the original tcvitals file here to ensure that SYNDATA will run if there
#   is something in the original tcvitals file

            DO_BOGUS=NO
            cp tcvitals_orig tcvitals
         else

#  If RELOCATION_HAS_RUN=YES, NET is not nam (currently meaning it is gfs or
#   gdas), and the tcvitals file generated by previous tropical cyclone
#   relocation processing has at least one record in it (which is usually NOT
#   the case) -- SYNDATA will run and WILL append bogus reports for the
#   storm(s) in the relocation-generated tcvitals file - it will also FLAG
#   dropwinsonde winds and/or mass pressure reports near the storm(s) (if
#   requested)
#
# %% But, then need to see if there were any other storms in the original
#   tcvitals file - if so, will set switch to run SYNDATA a SECOND time reading
#   in tcvitals records that were in original file but not in relocation-
#   generated tcvitals file - in this case SYNDATA will NOT append bogus
#   reports but it WILL flag dropwinsonde winds near storms (if requested) and
#   it will NOT flag mass pressure reports near storms (regardless of requested
#   switch)

            sort tcvitals_orig > tcvitals_orig_sort
            sort tcvitals > tcvitals_sort
            comm -23 tcvitals_orig_sort tcvitals_sort > tcvitals_removed
            [ -s tcvitals_removed ]  &&  run_syndat_twice=yes
         fi
      fi

      $TIMEIT $USHSYND/prepobs_syndata.sh  $DATA/prepda.${cycle} \
       $DATA/tcvitals $CDATE10

      if [ $run_syndat_twice = yes ]; then

#  Run SYNDATA a second time when switch "run_syndat_twice" was set to "yes" in
#   above logic (see %% above)

         DO_BOGUS=NO
         $TIMEIT $USHSYND/prepobs_syndata.sh  $DATA/prepda.${cycle} \
          $DATA/tcvitals_removed $CDATE10
      fi
   fi
fi

[ "$PREPDATA" = 'YES' ]  &&  cp prepda.${cycle} prepda.prepdata


###########################################
#  EXECUTE GSI QUALITY-CONTROL PROCESSING
###########################################

if [ "$DO_QC" = 'YES' ]; then
   if [ "$PREVENTS"  = 'YES' ];then
      $TIMEIT $USHPREV/prepobs_prevents.sh  $DATA/prepda.${cycle} $CDATE10
      errsc=$?
      [ "$errsc" -ne '0' ]  &&  exit $errsc
   fi
   if [ "$CQCBUFR"  = 'YES' ];then
      $TIMEIT $USHCQC/prepobs_cqcbufr.sh  $DATA/prepda.${cycle}
      errsc=$?
      [ "$errsc" -ne '0' ]  &&  exit $errsc
   fi
   if [ "$PROFCQC"  = 'YES' ];then
      $TIMEIT $USHPQC/prepobs_profcqc.sh  $DATA/prepda.${cycle}
      errsc=$?
      [ "$errsc" -ne '0' ]  &&  exit $errsc
   fi
   if [ "$CQCVAD"   = 'YES' ];then
      $TIMEIT $USHVQC/prepobs_cqcvad.sh   $DATA/prepda.${cycle} $CDATE10
      errsc=$?
      [ "$errsc" -ne '0' ]  &&  exit $errsc
   fi
   if [ "$PREPACQC" = 'YES' ];then
      $TIMEIT $USHAQC/prepobs_prepacqc.sh $DATA/prepda.${cycle} $DATA/adpsfc
      errsc=$?
      [ "$errsc" -ne '0' ]  &&  exit $errsc
   fi
   if [ "$OIQCBUFR" = 'YES' ];then
      $TIMEIT $USHOIQC/prepobs_oiqcbufr.sh $DATA/prepda.${cycle} $CDATE10
      errsc=$?
      [ "$errsc" -ne '0' ]  &&  exit $errsc
   fi
fi


# Look for "OVERLARGE" subsets in stdout (print out of bufrlib when subset
#  discarded because it is too big to fit in a BUFR message) -- post to
#  jlogfile if appropriate

msg=`grep "OVERLARGE SUBSET DISCARDED" $pgmout`
err=$?
if [ "$err" -eq '0' ]; then
   set +x
   echo
   echo "$msg"
   echo
   set -x
   [ -n "$jlogfile" ] && $DATA/postmsg "$jlogfile" "$msg"
fi

exit 0
