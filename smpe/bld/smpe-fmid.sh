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

#% package prepared product as base FMID (++FUNCTION)
#%
#% -?                 show this help message
#% -c smpe.yaml       use the specified config file
#% -d                 enable debug messages
#%
#% -c is required

prefix=ZWE                     # product prefix
parts=parts.txt                # parts known by SMP/E
mcs=SMPMCS.txt                 # SMPMCS header
allocScript=../content/scripts/allocate-dataset.sh  # script to allocate data set
csiScript=get-dsn.rex          # catalog search interface (CSI) script
cfgScript=get-config.sh        # script to read smpe.yaml config data
here=$(dirname $0)             # script location
me=$(basename $0)              # script name
debug=-d                      # -d or null, -d triggers early debug
#IgNoRe_ErRoR=1                # no exit on error when not null  #debug
set -x                                                          #debug

test "$debug" && echo && echo "> $me $@"

# ---------------------------------------------------------------------
# --- create & populate rel files
# ---------------------------------------------------------------------
function _relFiles
{
test "$debug" && echo && echo "> _relFiles $@"

# remove RELFILEs of previous run

# show everything in debug mode
test "$debug" && $here/$csiScript -d "${mcsHlq}.F*"
# get data set list (no debug mode to avoid debug messages)
datasets=$($here/$csiScript "${mcsHlq}.F*")
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

# create RELFILEs

# TODO dynamically determine required RELFILE size

# F1 - only SMP/E install related
dd="S${prefix}SAMP"
list=$(awk '/^'$dd'/{print $2}' $log/$parts \
     | grep -e ^${prefix}[[:digit:]] -e ^${prefix}MKDIR$)
_copyMvsMvs "${mvsI}.$dd" "${mcsHlq}.F1" "FB" "80" "PO" "5,2"

# F2 - all sample members except SMP/E install related
dd="S${prefix}SAMP"
list=$(awk '/^'$dd'/{print $2}' $log/$parts \
     | grep -v ^${prefix}[[:digit:]] | grep -v ^${prefix}MKDIR$)
_copyMvsMvs "${mvsI}.$dd" "${mcsHlq}.F2" "FB" "80" "PO" "5,2"

#TODO - no files in here, so empty?
# F3 - all load modules
# dd="S${prefix}AUTH"
# list=$(awk '/^'$dd'/{print $2}' $log/$parts)
# _copyMvsMvs "${mvsI}.$dd" "${mcsHlq}.F3" "U" "**" "PO" "5,2"

# F4 - all USS files
# half-track on 3390 DASD is 27998 bytes
# record length 6999 fits 4 records per half-track, with 2 bytes left
# subtract 4 for variable record length field gives LRECL(6995)
dd="S${prefix}ZFS"
list=$(awk '/^'$dd'/{print $2}' $log/$parts)
_copyUssMvs $ussI "${mcsHlq}.F4" "VB" "6995" "PO" "7500,750"

test "$debug" && echo "< _relFiles"
}    # _relFiles

# ---------------------------------------------------------------------
# --- create SMPMCS
# ---------------------------------------------------------------------
function _smpmcs
{
test "$debug" && echo && echo "> _smpmcs $@"

echo "-- create SMPMCS"

file="$here/$mcs"                                               # input
dsn="${mcsHlq}.SMPMCS"                                         # output

year=$(date '+%Y')                                               # YYYY
test "$debug" && year=$year
julian=$(date +%Y%j)                                          # YYYYddd
test "$debug" && julian=$julian

# validate/create target data set
$here/$allocScript $dsn "FB" "80" "PS" "1,1"
# returns 0 for OK, 1 for DCB mismatch, 2 for not pds(e), 8 for error
rc=$?
if test $rc -eq 0
then
  # customize SMPMCS
  SED="s/\[FMID\]/$FMID/g"             
  SED="$SED;s/\[YEAR\]/$year/g"        
  SED="$SED;s/\[DATE\]/$julian/g"      
  SED="$SED;s/\[RFDSNPFX\]/$RFDSNPFX/g"
  _cmd --repl $file.new sed "$SED" $file

  # TODO dynamically add parts processed by _relFiles()

  # TODO SMPMCS SUP existing service

  # move the customized file
  _cmd mv $file.new "//'$dsn'"
elif test $rc -eq 1
then
  echo "** ERROR $me data set $dsn exists with wrong DCB"
  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
else
  # Error details already reported
  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
fi    #

test "$debug" && echo "< _smpmcs"
}    # _smpmcs

# ---------------------------------------------------------------------
# --- copy MVS members defined in $list to specified data set
# $1: input data set name
# $2: output data set name
# $3: record format; {FB | U | VB}
# $4: logical record length, use ** for RECFM(U)
# $5: data set organisation; {PO | PS}
# $6: space in tracks; primary[,secondary]
# ---------------------------------------------------------------------
function _copyMvsMvs
{
test "$debug" && echo && echo "> _copyMvsMvs $@"

echo "-- populate $2 with $1"

# create target data set
$here/$allocScript "$2" "$3" "$4" "$5" "$6"
# returns 0 for OK, 1 for DCB mismatch, 2 for not pds(e), 8 for error
rc=$?
if test $rc -eq 0
then
  for member in $list
  do
    test "$debug" && echo member=$member

    # TODO test if $1($member) exists

    unset X                   # -X is required for copying load modules
    test "$3" = "U" && X="-X"
    # cp -X requires z/OS V2R2 UA96711, z/OS V2R3 UA96707 (August 2018)
    _cmd cp $X "//'$1($member)'" "//'$2($member)'"

    # TODO build SMPMCS data for this part

  done    # for file
elif test $rc -eq 1
then
  echo "** ERROR $me data set $2 exists with wrong DCB"
  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
else
  # Error details already reported
  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
fi    #

test "$debug" && echo "< _copyMvsMvs"
}    # _copyMvsMvs

# ---------------------------------------------------------------------
# --- copy USS files defined in $list to specified data set
# $1: input path
# $2: output data set name
# $3: record format; {FB | U | VB}
# $4: logical record length, use ** for RECFM(U)
# $5: data set organisation; {PO | PS}
# $6: space in tracks; primary[,secondary]
# ---------------------------------------------------------------------
function _copyUssMvs
{
test "$debug" && echo && echo "> _copyUssMvs $@"

echo "-- populate $2 with $1"

# validate/create target data set
$here/$allocScript "$2" "$3" "$4" "$5" "$6"
# returns 0 for OK, 1 for DCB mismatch, 2 for not pds(e), 8 for error
rc=$?
if test $rc -eq 0
then
for file in $list
  do
    test "$debug" && echo file=$file
    if test ! -f "$1/$file" -o ! -r "$1/$file"
    then
      echo "** ERROR $me cannot access $file"
      echo "ls -ld \"$1/$file\""; ls -ld "$1/$file"
      test ! "$IgNoRe_ErRoR" && exit 8                           # EXIT
    fi    #

    unset X                   # -X is required for copying load modules
    test "$3" = "U" && X="-X"
    # cp -X requires z/OS V2R2 UA96711, z/OS V2R3 UA96707 (August 2018)
    _cmd cp $X "$1/$file" "//'$2(${file%%.*})'"   # %%.* = no extension

    # TODO build SMPMCS data for this part

  done    # for file
elif test $rc -eq 1
then
  echo "** ERROR $me data set $2 exists with wrong DCB"
  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
else
  # Error details already reported
  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
fi    #

test "$debug" && echo "< _copyUssMvs"
}    # _copyUssMvs

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

# show input/output details
echo "-- input MVS: $mvsI"
echo "-- input USS: $ussI"
echo "-- output:    $mcsHlq"

# create SMP/E installable FMID

# TODO act upon parts delta (created by smpe-split.sh)
# - less parts requires explicit approval by build engineer
# - more parts results in warning mail to build engineer

_relFiles
_smpmcs

echo "-- completed $me 0"
test "$debug" && echo "< $me 0"
exit 0                                                           # EXIT
