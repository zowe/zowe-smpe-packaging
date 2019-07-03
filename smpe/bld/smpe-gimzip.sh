#!/bin/sh
#######################################################################
# This program and the accompanying materials are made available
# under the terms of the Eclipse Public License v2.0 which
# accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright Contributors to the Zowe Project. 2019, 2019
#######################################################################

#% package base FMID (++FUNCTION) for shipment in GIMZIP format
#%
#% -?                 show this help message
#% -c smpe.yaml       use the specified config file
#% -d                 enable debug messages
#%
#% -c is required
#%
#% caller needs these RACF permits:
#% ($0)
#% TSO PE BPX.SUPERUSER        CL(FACILITY) ACCESS(READ) ID(userid)
#% TSO PE GIM.PGM.GIMZIP       CL(FACILITY) ACCESS(READ) ID(userid)
#% TSO SETR RACLIST(FACILITY) REFRESH
#%
#% relies on IBM Developer for z Systems

# creates $gimzip                directory with pax & readme (ASCII)
# creates $log/$crastartLog      crastart output
# creates $log/$smpout           gimzip DD smpout output
# creates $log/$sysprint         gimzip DD sysprint output
# creates $log/$extractSize      required zFS size saved for usage in PD
# creates $log/$FMID.readme.txt  readme (EBCDIC)

extraTracks=90                 # add extra tracks to extract zFS size
product='Zowe Open Source Project'  # product name (max. 67 chars)
#        ----+----1----+----2----+----3----+----4----+----5----+----6----+--
crastartLog=crastart.log       # CRASTART execution log
crastartConf=crastart.conf     # generic CRASTART config file
readme=gimzip.readme.txt       # generic GIMZIP readme file
extractSize=extract-size.txt   # save required zFS size for PD creation
smpout=gimzip.smpout.log       # GIMZIP SMPOUT log
sysprint=gimzip.sysprint.log   # GIMZIP SYSPRINT log
sysinGimzip=sysin.gimzip       # generated SYSIN for GIMZIP
sysinGimunzip=sysin.gimunzip   # generated SYSIN for GIMUNZIP
csiScript=get-dsn.rex          # catalog search interface (CSI) script
existScript=../content/scripts/check-dataset-exist.sh  # script to test if data set exists
allocScript=../content/scripts/allocate-dataset.sh  # script to allocate data set
cfgScript=get-config.sh        # script to read smpe.yaml config data
here=$(dirname $0)             # script location
me=$(basename $0)              # script name
#debug=-d                      # -d or null, -d triggers early debug
#IgNoRe_ErRoR=1                # no exit on error when not null  #debug
#set -x                                                          #debug

test "$debug" && echo && echo "> $me $@"

# ---------------------------------------------------------------------
# --- invoke GIMZIP to create pax files & metadata for SMPMCS & RELFILEs
# $1: GIMZIP output directory
#
# GIMZIP is created for MVS batch invocation. We are using CRASTART,
# part of IBM Developer for z Systems, to create this environment.
# For this, CRASTART uses a config file, which acts very much like a
# simple JCL. DDs are defined and a program to execute is specified.
#
# documentation in "SMP/E for z/OS Reference (SA23-2276)" and
# "IBM Developer for z Systems Host Configuration Guide (SC27-8577)"
#
# user must be authorized to use this utility:
# - SYS1.MIGLIB(GIMZIP) packaging service routine
# - FEK.SFEKLPA(CRASTART) CARMA startup utility
#   (mapped in USS to /usr/lpp/IBM/idz/bin/CRASTART)
# ---------------------------------------------------------------------
function _gimzip
{
test "$debug" && echo && echo "> _gimzip $@"

echo "-- invoking GIMZIP"

if test ! -e "$CRASTART"
then
  echo "** ERROR $me cannot execute: $CRASTART"
  echo "ls -ld \"$CRASTART\""; ls -ld "$CRASTART"
  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
fi    #

# create metadata describing what GIMZIP & GIMUNZIP must process
_gimzipMeta

# create customized config file used by CRASTART to run GIMZIP
_cmd --repl $scratch/$crastartConf \
  sed "s!#dir!$scratch!g;s/#fmid/$FMID/g;s/#hlq/$gimzipHlq/g" \
    $here/$crastartConf
test "$debug" && cat $scratch/$crastartConf

# CRASTART is not designed to handle lowercase paths, so create
# uppercase symbolic links (assumes $scratch is all uppercase)
# KEEP IN SYNC WITH $here/$crastartConf
_ln $SMPCPATH $scratch/SMPCPATH
_ln $SMPJHOME $scratch/SMPJHOME
_ln $1        $scratch/SMPDIR

# allocate & populate data sets used by GIMZIP
# note: GIMZIP assumes FB80 for SYSIN and will abend if this is not so
# note: GIMZIP assumes FBA121 for output and does not write \n, so
# writing directly to a USS file results in all output on a single line
# KEEP IN SYNC WITH $here/$crastartConf
_alloc "${gimzipHlq}.SMPOUT"   "FBA" "121" "PS" "1,1"
_alloc "${gimzipHlq}.SYSPRINT" "FBA" "121" "PS" "1,1"
_alloc "${gimzipHlq}.SYSIN"    "FB"   "80" "PS" "1,1"
_cmd cp $scratch/$sysinGimzip "//'${gimzipHlq}.SYSIN'"

# set CRASTART log level (always All so we can parse GIMZIP RC message)
# A (All):       all trace messages
# P (Partial):   only connect, disconnect and error messages
# anything else: only error messages
crastartLogLevel="All"
test "$debug" && echo crastartLogLevel=$crastartLogLevel

# STEPLIB is in use by the CRASTART invocation, so tell CRASTART to
# treat DD TASKLIB as STEPLIB for GIMZIP
crastartTaskLibDD='TASKLIB'
test "$debug" && echo crastartTaskLibDD=$crastartTaskLibDD

# any supported EXEC PGM=GIMZIP,PARM='...' parameter
gimzipParm=''
test "$debug" && echo gimzipParm=$gimzipParm

# execute CRASTART and tell it to run GIMZIP
# note: CRASTART invocation is modelled after invocation done by
# IBM Developer for z Systems in carma.startup.rex
_cmd --repl $log/$crastartLog "$CRASTART $gimzipParm" \
  "TASKLIB=$crastartTaskLibDD" \
  "SYSLOG=$crastartLogLevel" \
  "FILE=$scratch/$crastartConf"

# give z/OS time to free the data sets before accessing them again
# cp: FSUM6258 cannot open file "//'...'": EDC5061I An error occurred 
# when attempting to define a file to the system. (errno2=0xC00B0403)
_cmd sleep 2

# save GIMZIP output in log directory
_cmd cp "//'${gimzipHlq}.SYSPRINT'" $log/$sysprint
_cmd cp "//'${gimzipHlq}.SMPOUT'" $log/$smpout

# did GIMZIP fail ?
# success: CRAD0007I IBMUSER GIMZIP   Attach Hex:0 Dec:0
# failure: CRAD1002W IBMUSER ALLOC DD(SMPCPATH) PATH('/USR/LPP/JAVA/J8.0/BIN')
#          CRAD1003W IBMUSER DYNALLOC return Hex:FFFF8017 Dec:-32745
# failure: CRAD1001W IBMUSER GIMZIP  Returned 001000, May be ABEND 001
# grep 1 will remove lines without message ID
# grep 2 will remove all Informational messages, except CRAD0007I
# grep 3 will remove lines ending in Dec:0 (sign of success)
# failure if any line is left (non-zero completion or Warning/Error)
if test "$(cat $log/$crastartLog \
           | grep ^CRA | grep -v ^CRAD000[^7]I | grep -v Dec:0$)"
then                                       # CRASTART or GIMZIP failure
  test "$debug" && echo "CRASTART or GIMZIP failure"
  echo "-- $crastartLog $(cat $log/$crastartLog | wc -l) line(s)"
  cat $log/$crastartLog
  echo "-- $sysprint $(cat $log/$sysprint | wc -l) line(s)"
  cat $log/$sysprint
  echo "-- $smpout $(cat $log/$smpout | wc -l) line(s)"
  cat $log/$smpout
  echo "** ERROR $me GIMZIP ended with a non-zero return code"
  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
elif test "$debug"                                     # GIMZIP success
then
  echo "GIMZIP successful"
  _cmd cat $log/$crastartLog
  _cmd cat $log/$sysprint
  _cmd cat $log/$smpout
fi    #

test "$debug" && echo "< _gimzip"
}    # _gimzip

# ---------------------------------------------------------------------
# --- create SYSIN metadata for GIMZIP & GIMUNZIP
# GIMZIP sample:
# <GIMZIP description="Zowe Open Source Project">
# <FILEDEF type="SMPPTFIN" archid="SMPMCS"
#          name="BLD.ZOWE.AZWE001.SMPMCS"/>
# <FILEDEF type="SMPRELF"  archid="AZWE001.F1"
#          name="BLD.ZOWE.AZWE001.F1"/>
# </GIMZIP>
#
# GIMUNZIP sample:
# <GIMUNZIP>
# <ARCHDEF archid="SMPMCS"
#          newname="@PREFIX@.ZOWE.AZWE001.SMPMCS"/>
# <ARCHDEF archid="AZWE001.F1"
#          newname="@PREFIX@.ZOWE.AZWE001.F1"/>
# </GIMUNZIP>
#
# documentation in "SMP/E for z/OS Reference (SA23-2276)"
# ---------------------------------------------------------------------
function _gimzipMeta
{
test "$debug" && echo && echo "> _gimzipMeta $@"

# get SMPMCS
mcs="${mcsHlq}.SMPMCS"
$here/$existScript $mcs
# returns 0 for exist, 2 for not exist, 8 for error
if test $rc -eq 2
then
  echo "** ERROR $me no data sets match '$mcs'"
  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
elif test $rc -gt 2
then
  # error details already reported
  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
fi    #

# get RELFILEs
mask="${mcsHlq}.F*"
# show everything in debug mode
test "$debug" && $here/$csiScript -d "$mask"
# get data set list (no debug mode to avoid debug messages)
datasets=$($here/$csiScript "$mask")
# returns 0 for match, 1 for no match, 8 for error
rc=$?
if test $rc -eq 1
then
  echo "** ERROR $me no data sets match '$mask'"
  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
elif test $rc -gt 1
then
  echo "$datasets"                       # variable holds error message
  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
fi    #

# verify that all DSNs end in .F<number>
if test "$(echo "$datasets" | grep -v \.F[[:digit:]]*$)"
then
  echo "** ERROR $me non-RELFILE data set in RELFILE list"
  echo "$datasets" | grep -v \.F[[:digit:]]*$
  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
fi    #

# GIMZIP SYSIN header
_cmd --repl $scratch/$sysinGimzip \
  echo "<GIMZIP description=\"$product\">"
_cmd --save $scratch/$sysinGimzip \
  echo "<FILEDEF type=\"SMPPTFIN\" archid=\"SMPMCS\""
_cmd --save $scratch/$sysinGimzip \
  echo "         name=\"$mcs\"/>"

# GIMUNZIP SYSIN header
_cmd --repl $scratch/$sysinGimunzip \
  echo "<GIMUNZIP>"
_cmd --save $scratch/$sysinGimunzip \
  echo "<ARCHDEF archid=\"SMPMCS\""
_cmd --save $scratch/$sysinGimunzip \
  echo "         newname=\"@PREFIX@.${RFDSNPFX}.${FMID}.SMPMCS\"/>"

# add RELFILEs to SYSIN
for dsn in $datasets
do
  test "$debug"&&  echo dsn=$dsn

  # ${dsn##*.} -> keep from last . (exclusive) = low level qualifier
  #GIMZIP
  _cmd --save $scratch/$sysinGimzip \
    echo "<FILEDEF type=\"SMPRELF\"  archid=\"${FMID}.${dsn##*.}\""
  _cmd --save $scratch/$sysinGimzip \
    echo "         name=\"$dsn\"/>"

  #GIMUNZIP
  _cmd --save $scratch/$sysinGimunzip \
  echo "<ARCHDEF archid=\"${FMID}.${dsn##*.}\""
  _cmd --save $scratch/$sysinGimunzip \
  echo "         newname=\"@PREFIX@.${RFDSNPFX}.${FMID}.${dsn##*.}\"/>"
done    # for f

# GIMZIP SYSIN footer
_cmd --save $scratch/$sysinGimzip echo "</GIMZIP>"

# GIMUNZIP SYSIN footer
_cmd --save $scratch/$sysinGimunzip echo "</GIMUNZIP>"

test "$debug" && cat $scratch/$sysinGimzip
test "$debug" && cat $scratch/$sysinGimunzip

test "$debug" && echo "< _gimzipMeta"
}    # _gimzipMeta

# ---------------------------------------------------------------------
# --- create symbolic link
# $1: old path
# $2: new path (symbolic link to old path)
# ---------------------------------------------------------------------
function _ln
{
test "$debug" && echo && echo "> _ln $@"

test -e $2 && _cmd rm -f $2
_cmd ln -s $1 $2

test "$debug" && echo "< _ln"
}    # _ln

# ---------------------------------------------------------------------
# --- allocate data set
# $1: data set name
# $2: record format; {FB | U | VB}
# $3: logical record length, use ** for RECFM(U)
# $4: data set organisation; {PO | PS}
# $5: space in tracks; primary[,secondary]
# ---------------------------------------------------------------------
function _alloc
{
test "$debug" && echo && echo "> _alloc $@"

# remove previous run
$here/$existScript "$1"
# returns 0 for exist, 2 for not exist, 8 for error
rc=$?
if test $rc -eq 0
then
  _cmd2 --null tsocmd "DELETE '$1'"
elif test $rc -gt 2
then
  # error details already reported
  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
fi    #

# create target data set
$here/$allocScript -h "$1" "$2" "$3" "$4" "$5"
# returns 0 for OK, 1 for DCB mismatch, 2 for not pds(e), 8 for error
rc=$?
if test $rc -gt 0
then
  if test $rc -eq 1
  then
    echo "** ERROR $me data set $1 exists with wrong DCB"
    test ! "$IgNoRe_ErRoR" && exit 8                             # EXIT
  else
    # error details already reported
    test ! "$IgNoRe_ErRoR" && exit 8                             # EXIT
  fi    #
fi    # rc > 0

test "$debug" && echo "< _alloc"
}    # _alloc

# ---------------------------------------------------------------------
# --- create pax file
# sets $paxFile
# $1: GIMZIP output directory, also used as base for pax name
# ---------------------------------------------------------------------
function _pax
{
test "$debug" && echo && echo "> _pax $@"

echo "-- creating FMID pax"

paxFile="${FMID}.pax.Z"
_cmd cd $1
# pax
#  -w                  write
#  -f ${paxfile}       output file
#  -x pax              save using pax interchange format
#  -z                  compress
#  ${paxask}          input filter
paxOpt="-w -f ../$paxFile -x pax -z ./*"
_cmd pax $paxOpt
_cmd cd - >/dev/null

test "$debug" && echo "< _pax"
}    # _pax

# ---------------------------------------------------------------------
# --- determine required space for extract, add extra for zFS overhead
# sets $size
# $1: GIMZIP output directory
# ---------------------------------------------------------------------
function _size
{
test "$debug" && echo && echo "> _size $@"

test "$debug" && _cmd ls -lRA ${1}*
# sum size of all parts in tracks (56,664 bytes/track on 3390 DASD)
AWK='{if ($5 != "") bytes += $5} END  \
     {printf "%d",(bytes/56664)+'extraTracks'}'
primary=$(ls -lRA ${1}* | awk "$AWK")

# save value so it can be used during program directory creation
_cmd --repl $log/$extractSize echo $primary

# calculate secondary allocation size for extract zFS
let secondary=$primary/10         # size of extent is 1/10th of primary
size="$primary $secondary"
test "$debug" && echo size=$size

test "$debug" && echo "< _size"
}    # _size

# ---------------------------------------------------------------------
# --- create readme file
# ---------------------------------------------------------------------
function _readme
{
test "$debug" && echo && echo "> _readme $@"

echo "-- creating FMID readme"

# create bulk of customized readme (in EBCDIC)
SED="s/#product/$product/g"       # sed is picky about blanks in script
SED="$SED;s/#size/$size/g"
SED="$SED;s/#readme/${FMID}.readme.txt/g"
SED="$SED;s/#pax/$paxFile/g"
test "$debug" && echo     # cannot use _cmd as the quotes get messed up
test "$debug" && echo "sed \"$SED\" $here/$readme 2>&1 > $log/$readme"
sed "$SED" $here/$readme 2>&1 > $log/$readme
sTaTuS=$?
if test $sTaTuS -ne 0
then
  echo "** ERROR $me 'sed \"$SED\" $here/$readme' ended with status $sTaTuS"
  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
fi    #

# add GIMUNZIP SYSIN data
_cmd --save $log/$readme cat $scratch/$sysinGimunzip

# add footer, no _cmd to avoid expanding '*'
echo '//*' >> $log/$readme

# save readme in ASCII for easy transfer with pax file
_cmd --repl $gimzip/${FMID}.readme.txt \
  iconv -t ISO8859-1 -f IBM-1047 $log/$readme

test "$debug" && echo "< _readme"
}    # _readme

# ---------------------------------------------------------------------
# --- show & execute command as UID 0, and bail with message on error
#     stderr is routed to stdout to preserve the order of messages
# $1: if --null then trash stdout, parm is removed when present
# $1: if --save then append stdout to $2, parms are removed when present
# $1: if --repl then save stdout to $2, parms are removed when present
# $2: if $1 = --save or --repl then target receiving stdout
# $@: command with arguments to execute
# ---------------------------------------------------------------------
function _super
{
test "$debug" && echo

if test "$1" = "--null"
then         # stdout -> null, stderr -> stdout (without going to null)
  shift
  test "$debug" && echo "echo \"$@\" | su 2>&1 >/dev/null"
                         echo  "$@"  | su 2>&1 >/dev/null
elif test "$1" = "--save"
then         # stdout -> >>$2, stderr -> stdout (without going to $2)
  sAvE=$2
  shift 2
  test "$debug" && echo "echo \"$@\" | su 2>&1 >> $sAvE"
                         echo  "$@"  | su 2>&1 >> $sAvE
elif test "$1" = "--repl"
then         # stdout -> >$2, stderr -> stdout (without going to $2)
  sAvE=$2
  shift 2
  test "$debug" && echo "echo \"$@\" | su 2>&1 > $sAvE"
                         echo  "$@"  | su 2>&1 > $sAvE
else         # stderr -> stdout, caller can add >/dev/null to trash all
  test "$debug" && echo "echo \"$@\" | su 2>&1"
                         echo  "$@"  | su 2>&1
fi    #
status=$?

if test $status -ne 0
then
    echo "** ERROR $me '$@' ended with status $sTaTuS"
  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
fi    #
}    # _super

# ---------------------------------------------------------------------
# --- show & execute command, and bail with message on error
#     stderr is always trashed
# $1: if --null then trash stdout, parm is removed when present
# $1: if --save then append stdout to $2, parms are removed when present
# $1: if --repl then save stdout to $2, parms are removed when present
# $2: if $1 = --save or --repl then target receiving stdout
# $@: command with arguments to execute
# ---------------------------------------------------------------------
function _cmd2
{
test "$debug" && echo
if test "$1" = "--null"
then                                 # stdout -> null, stderr -> null
  shift
  test "$debug" && echo "$@ 2>/dev/null >/dev/null"
                         $@ 2>/dev/null >/dev/null
elif test "$1" = "--save"
then                                 # stdout -> >>$2, stderr -> null
  sAvE=$2
  shift 2
  test "$debug" && echo "$@ 2>/dev/null >> $sAvE"
                         $@ 2>/dev/null >> $sAvE
elif test "$1" = "--repl"
then                                 # stdout -> >$2, stderr -> null
  sAvE=$2
  shift 2
  test "$debug" && echo "$@ 2>/dev/null > $sAvE"
                         $@ 2>/dev/null > $sAvE
else                                 # stdout -> stdout, stderr -> null
  test "$debug" && echo "$@ 2>/dev/null"
                         $@ 2>/dev/null
fi    #
sTaTuS=$?
if test $sTaTuS -ne 0
then
    echo "** ERROR $me '$@' ended with status $sTaTuS"
  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
fi    #
}    # _cmd2

# ---------------------------------------------------------------------
# --- show & execute command, and bail with message on error
#     stderr is routed to stdout to preserve the order of messages
# $1: if --null then trash stdout, parm is removed when present
# $1: if --save then append stdout to $2, parms are removed when present
# $1: if --repl then save stdout to $2, parms are removed when present
# $2: if $1 = --save or --repl then target receiving stdout
# $@: command with arguments to execute
# ---------------------------------------------------------------------
function _cmd
{
test "$debug" && echo
if test "$1" = "--null"
then         # stdout -> null, stderr -> stdout (without going to null)
  shift
  test "$debug" && echo "$@ 2>&1 >/dev/null"
                         $@ 2>&1 >/dev/null
elif test "$1" = "--save"
then         # stdout -> >>$2, stderr -> stdout (without going to $2)
  sAvE=$2
  shift 2
  test "$debug" && echo "$@ 2>&1 >> $sAvE"
                         $@ 2>&1 >> $sAvE
elif test "$1" = "--repl"
then         # stdout -> >$2, stderr -> stdout (without going to $2)
  sAvE=$2
  shift 2
  test "$debug" && echo "$@ 2>&1 > $sAvE"
                         $@ 2>&1 > $sAvE
else         # stderr -> stdout, caller can add >/dev/null to trash all
  test "$debug" && echo "$@ 2>&1"
                         $@ 2>&1
fi    #
sTaTuS=$?
if test $sTaTuS -ne 0
then
  echo "** ERROR $me '$@' ended with status $sTaTuS"
  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
fi    #
}    # _cmd

# ---------------------------------------------------------------------
# --- display script usage information
# ---------------------------------------------------------------------
function _displayUsage
{
echo " "
echo " $me"
sed -n 's/^#%//p' $(whence $0)
echo " "
}    # _displayUsage

# ---------------------------------------------------------------------
# --- main --- main --- main --- main --- main --- main --- main ---
# ---------------------------------------------------------------------
function main { }     # dummy function to simplify program flow parsing

# misc setup
_EDC_ADD_ERRNO2=1                               # show details on error
unset ENV             # just in case, as it can cause unexpected output
_cmd umask 0022                                  # similar to chmod 755

echo; echo "-- $me - start $(date)"
echo "-- startup arguments: $@"

# . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .

# clear input variables
unset YAML in
# do NOT unset debug

# get startup arguments
while getopts c:i:?d opt
do case "$opt" in
  c)   YAML="$OPTARG";;
  d)   debug="-d";;
  [?]) _displayUsage
       test $opt = '?' || echo "** ERROR $me faulty startup argument: $@"
       test ! "$IgNoRe_ErRoR" && exit 8;;                        # EXIT
  esac    # $opt
done    # getopts
shift $OPTIND-1

# set envvars
. $here/$cfgScript -c                         # call with shell sharing
if test $rc -ne 0
then
  # error details already reported
  echo "** ERROR $me '. $here/$cfgScript' ended with status $rc"
  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
fi    #

# . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .

mcsHlq=${HLQ}.${RFDSNPFX}.${FMID}

echo "-- input:  $mcsHlq"
echo "-- output: $gimzip"

SMPJHOME=$JAVA_HOME                                         # Java home
SMPCPATH=$SMP_HOME/classes                         # SMP/E Java classes
CRASTART=$IDZ_HOME/bin/CRASTART                    # CRASTART lmod stub

base=$gimzip/$FMID        # pax, readme & work dir all start with $FMID
# $scratch must be all uppercase for CRASTART
scratch=$(echo $scratch | tr [:lower:] [:upper:])

# clean up output of previous run
# note: GIMZIP creates data owned by UID 0
test -x "$scratch" && _cmd rm -rf $scratch  # remove temporary work dir
_cmd mkdir -p $scratch                      # create temporary work dir
_cmd mkdir -p $gimzip                               # create output dir
_cmd touch $base                           # make sure something exists
_super rm -rf $base*            # remove pax, readme, & GIMZIP work dir
_cmd mkdir -p $base                            # create GIMZIP work dir

# stage SMPMCS, RELFILEs, and GIMZIP metadata
_gimzip $base

# create pax file
_pax $base

# determine size of zFS needed to extract pax file
_size $base

# create readme file
_readme

# cleanup
_super rm -rf $base                            # remove GIMZIP work dir
_cmd rm -rf $scratch                        # remove temporary work dir
# show everything in debug mode            # remove temporary data sets
test "$debug" && $here/$csiScript -d "${gimzipHlq}.*"
# get data set list (no debug mode to avoid debug messages)
datasets=$($here/$csiScript "${gimzipHlq}.*")
# returns 0 for match, 1 for no match, 8 for error
if test $? -gt 1
then
  echo "$datasets"                       # variable holds error message
  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
fi    #
# delete data sets
for dsn in $datasets
do
  _cmd2 --null tsocmd "DELETE '$dsn'"
done    # for dsn

echo "-- completed $me 0"
test "$debug" && echo "< $me 0"
exit 0                                                           # EXIT
