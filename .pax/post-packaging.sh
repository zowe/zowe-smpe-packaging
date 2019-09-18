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

FUNC=[CreatePax][post-packaging]
CURR_PWD=$(pwd)
INPUT_TXT=input.txt

if [ -z "${ZOWE_VERSION}" ]; then
  echo "$FUNC[ERROR] ZOWE_VERSION environment variable is missing"
  exit 1
fi
ZOWE_VERSION_MAJOR=$(echo "${ZOWE_VERSION}" | awk -F. '{print $1}')
# FIXME: what happened if ZOWE_VERSION_MAJOR>10
FMID_VERISON="00${ZOWE_VERSION_MAJOR}"

# display extracted files
echo "$FUNC content of $CURR_PWD...."
find . -print

# find zowe pax
ZOWE_PAX=$(ls -1 zowe-*.pax | grep -v smpe)
if [ -z "${ZOWE_PAX}" ]; then
  echo "$FUNC[ERROR] Cannot find Zowe package."
  exit 1
fi
echo "$FUNC Zowe package is: ${ZOWE_PAX}"

SMPE_PAX=
if [ -f "zowe-smpe.pax" ]; then
  mv zowe-smpe.pax smpe.pax
  SMPE_PAX=smpe.pax
else
  echo "$FUNC[ERROR] smpe.pax is not created."
  exit 10
fi

echo "$FUNC preparing ${INPUT_TXT} ..."
echo "${CURR_PWD}/${ZOWE_PAX}" > "${INPUT_TXT}"
echo "${CURR_PWD}/${SMPE_PAX}" >> "${INPUT_TXT}"
echo "$FUNC content of ${INPUT_TXT}:"
cat "${INPUT_TXT}"
mkdir -p zowe

./bld/smpe.sh -i "${CURR_PWD}/${INPUT_TXT}" -v ${FMID_VERISON} -r "${CURR_PWD}/zowe" -d

# get the final build result
ZOWE_SMPE_PAX="${CURR_PWD}/zowe/AZWE${FMID_VERISON}/gimzip/AZWE${FMID_VERISON}.pax.Z"
if [ -z "${ZOWE_SMPE_PAX}" ]; then
  echo "$FUNC[ERROR] cannot find build result zowe/AZWE${FMID_VERISON}/gimzip/AZWE${FMID_VERISON}.pax.Z"
  exit 1
fi
ZOWE_SMPE_README="${CURR_PWD}/zowe/AZWE${FMID_VERISON}/gimzip/AZWE${FMID_VERISON}.readme.txt"
if [ -z "${ZOWE_SMPE_README}" ]; then
  echo "$FUNC[ERROR] cannot find build result zowe/AZWE${FMID_VERISON}/gimzip/AZWE${FMID_VERISON}.readme.txt"
  exit 1
fi
mv "${ZOWE_SMPE_PAX}" "${CURR_PWD}/zowe-smpe.pax"
mv "${ZOWE_SMPE_README}" "${CURR_PWD}/readme.txt"

# prepare rename to original name
echo "mv zowe-smpe.pax AZWE${FMID_VERISON}.pax.Z" > "${CURR_PWD}/rename-back.sh.1047"
echo "mv readme.txt AZWE${FMID_VERISON}.readme.txt" >> "${CURR_PWD}/rename-back.sh.1047"
iconv -f IBM-1047 -t ISO8859-1 rename-back.sh.1047 > rename-back.sh
