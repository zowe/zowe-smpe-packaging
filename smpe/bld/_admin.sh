#!/bin/sh
#
# build admin.pax
#
root=$(dirname $0) ; cd $root ; root=$PWD

echo "set stage"
chmod 755 $(find $root/_new -level 0 -type f) 2>&1
chtag -r  $(find $root/_new -level 0 -type f) 2>&1
rm -r $root/_new/tmp 2>/dev/null

rm -r $root/_new/pax/admin.pax 2>/dev/null
mkdir -p $root/_new/pax 2>&1
mkdir -p $root/_new/tmp 2>&1
cd $root/_new/tmp 2>&1

echo "rebuild"
mkdir -p admin 2>&1
cp ../zowe-configure-RESTORE.sh \
   ../zowe-configure.sh \
   ../zowe-start.sh \
   ../zowe-stop.sh \
   $dir/admin 2>&1
#   ../zowe-activate.sh \
#  ../zowe-validate-config-file.sh \

echo "create pax"
pax -w -f ../pax/admin.pax -s#$(pwd)## -o saveext -px $(ls -A) 2>&1

echo "cleanup"
cd $root/_new 2>&1
rm -r $root/_new/tmp 2>&1

echo "verify pax"
pax -f pax/admin.pax 2>&1

