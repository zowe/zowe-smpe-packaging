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
echo "$FUNC content of $PWD...."
find . -print

cd content

# run test
./scripts/hello.sh

# run smpe.sh
./scripts/smpe.sh -?
