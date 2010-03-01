#!/bin/sh

# redisversion=redis-1.1.91-beta
redisversion=redis-1.2.2

#
# Check whether this version of redis is already installed
#
if [ -d $redisversion ]; then
  echo =============================
  echo FAILURE: $redisversion is already installed.
  echo If you really want to reinstall,
  echo you will have to remove it yourself
  echo =============================
  exit -1
fi

#
# Check whether any redis-server* is running
#
if [ `ps ax | grep redis-server | grep -v grep | wc -l` -gt 0 ]; then
  echo =============================
  echo FAILED redis-server or partition is already running
  echo You must manually \"kill -9 PID\"
  echo perhaps: `ps ax | grep redis-server | grep -v grep | sed "s: .*::" | sed "s:^:kill -9 :"`
  echo =============================
  ps ax | grep redis-server | grep -v grep
  echo =============================
  exit -1
fi

#
# Set the 'skip' command line argument
# (undocumented feature)
# if set, skip installing gcc, make test, and benchmark
#
if [ "$1" = "skip" ]; then
  skip=skip
fi

if [ ! $skip ]; then

  echo =============================
  echo Installing gcc
  echo =============================

  yum install gcc

fi

echo =============================
echo Extracting $redisversion
echo =============================

tar xf ${redisversion}.tar.gz

#
# Change to newly extracted directory
#
cd $redisversion

echo =============================
echo Compiling $redisversion
echo =============================

make

echo =============================
echo Starting server
echo in the background
echo =============================

./redis-server > test-server.log &

if [ ! $skip ]; then

  echo =============================
  echo Running test
  echo =============================

  make test

  echo =============================
  echo Running benchmark
  echo =============================

  ./redis-benchmark 

fi

# echo =============================
# echo Cleanup source, etc
# echo =============================
# 
# mkdir src
# mv -f 00* *.c *.h *.o *txt BUGS Changelog client-libraries COPYING design-documents doc Makefile README redis.conf redis-benchmark TODO utils redis.tcl test-redis.tcl src

#
# Kill the redis-server process
#
echo =============================
echo Killing redis-server used in tests
ps ax | grep redis-server | grep -v grep | sed "s: .*::" | sed "s:^:kill -9 :" | sh
if [ `ps ax | grep [0-9]../redis-server | wc -l` -gt 0 ]; then
  echo FAILED to kill process
  echo You must manually \"kill -9 PID\"
  echo perhaps: `ps ax | grep redis-server | grep -v grep | sed "s: .*::" | sed "s:^:kill -9 :"`
fi
echo =============================
rm -f dump.rdb
cd ..

echo =============================
echo Done
echo =============================
