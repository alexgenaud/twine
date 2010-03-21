#!/bin/bash

SERVERSUFFIX=redis-server-1.2.5
USE_HOST=$1

# if no arguments, then we must be sure
# there is only one host in the partitions directory
if [ $# -eq 0 ]; then
  USE_HOST=_BOGUS_DIRECTORY_
  if [ `ls partitions|wc -l` -eq 1 ]; then
    if [ -r partitions/`ls partitions` ]; then 
      USE_HOST=`ls partitions`
    fi
  fi
fi

if ! [ -r partitions/$USE_HOST ]; then
  echo usage: twine-start HOST
  ls partitions
  exit 1
fi

cd partitions/${USE_HOST}
for server in `find -mindepth 1 -maxdepth 1 -type d`; do
  cd $server
  sh start.sh
  cd ..
done;
cd ../..

exit 0
