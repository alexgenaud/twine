#!/bin/bash

SERVERSUFFIX=redis-server-1.2.2

for server in `ls partitions`; do
  cd partitions/$server
  ./${server}-${SERVERSUFFIX} redis.conf 1> access.log 2> error.log &
  cd ../..
done;

exit 0
