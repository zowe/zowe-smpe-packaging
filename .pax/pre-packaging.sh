#!/bin/sh -e
set -x

################################################################################
# This program and the accompanying materials are made available under the terms of the
# Eclipse Public License v2.0 which accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright IBM Corporation 2019
################################################################################

FUNC=[CreatePax][pre-packaging]
PWD=$(pwd)

# display extracted files
echo "$FUNC content of $PWD before pre-packaging ...."
find . -print

# convert line endings
echo "$FUNC removing windows line ending x0D ..."
for f in $(find content -type f)
do
  sed "s/$(printf '\x0D')$//" $f 2>&1 > $f.new && mv $f.new $f 2>&1
done

# make sure execute permission
echo "$FUNC adjust execute permissions ..."
chmod -R 755 content

# prepare /bld
echo "$FUNC bld is not part of smpe.pax, moving out ..."
mv content/bld .

# display extracted files
echo "$FUNC content of $PWD after pre-packaging ...."
find . -print
