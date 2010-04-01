#!/bin/bash

if [ $# -lt 1 ]; then
  echo FAILURE: usage twine-restore archive.zip
  exit 1
elif [ `unzip -t $1|grep "No errors detected"|wc -l` -ne 1 ]; then
  echo FAILURE: usage twine-restore archive.zip
  exit 1
elif [ -r partitions ]; then
  mkdir -p backup
  DATE=`date -u +%Y%m%d.%H%M%S`
  echo backup/partitions.mv.$DATE.zip
  zip -9ryq backup/partitions.mv.$DATE.zip partitions
  rm -rf partitions
fi
unzip -q $1
exit 0
