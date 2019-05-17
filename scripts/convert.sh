#!/bin/sh
for f in .
do
  echo "Processing $f file..."
  iconv -f ISO8859-1 -t IBM-1047 $f > temp
  mv temp $f
done