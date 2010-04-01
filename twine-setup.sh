#!/bin/bash

REDISVERSION=redis-1.2.6
SERVERSUFFIX=redis-server-1.2.6
MONIT_DAEMON_SEC=1
REDIS_SAVE_SEC=10
USE_HOST=$1
APPENDONLY=no

if [ $# -lt 1 ] ; then
  echo twine-setup all partitions for all hosts
else
  echo twine-setup only partitions for host: $1
fi

# check that the twine.conf file exists and is readable
if ! [ -r twine.conf ]; then
  echo =============================
  echo Error: Unable to read twine.conf
  echo =============================
  exit 1
fi

# check that every line of twine.conf is valid
cat twine.conf | while read -r LINE; do
  if [ `echo $LINE | grep -E \
       "^[a-zA-Z0-9\._-]+=(data [0-9]+|status) [a-zA-Z0-9\._-]+ [0-9]+ [0-9]+$"\
       | wc -c` -gt 20 ]; then 
    continue;
  elif [ `echo $LINE | grep "^#" | wc -l` = 1 ]; then
    continue;
  elif [ `echo $LINE | grep "^[\w]*$" | wc -l` = 1 ]; then
    continue;
  else
    echo =============================
    echo Error in twine.conf
    echo INVALID: $LINE
    echo =============================
    exit 1
  fi
done

# check that partitions directory does not exist
if [ -e partitions ]; then
  echo =============================
  echo Error: partitions directory already exists
  echo =============================
  exit 1
fi

echo =============================
echo Creating partitions directory
echo =============================
mkdir partitions


cat twine.conf | while read -r LINE; do
  if [ `echo $LINE | grep -E \
       "^[a-zA-Z0-9\._-]+=(data [0-9]+|status) [a-zA-Z0-9\._-]+ [0-9]+ [0-9]+$"\
       | wc -c` -gt 20 ]; then 
    if [ `echo $LINE | grep "^.*data" | wc -c` -gt 20 ]; then 
      LINETYPE=data
      NAME=`echo $LINE |sed s:=.*::`
      PART=`echo $LINE |awk '{ print $2 }'`
      HOST=`echo $LINE |awk '{ print $3 }'`
      PORT=`echo $LINE |awk '{ print $4 }'`
        DB=`echo $LINE |awk '{ print $5 }'`
    elif [ `echo $LINE | grep "^.*=status" | wc -c` -gt 20 ]; then 
      LINETYPE=status
      NAME=`echo $LINE |sed s:=.*::`
      HOST=`echo $LINE |awk '{ print $2 }'`
      PORT=`echo $LINE |awk '{ print $3 }'`
        DB=`echo $LINE |awk '{ print $4 }'`
    else
      echo NONESENSE
    fi # data or status line

    if [ "_${USE_HOST}" != "_" -a "_${USE_HOST}" != "_${HOST}" ]; then
      continue
    fi

    PART_PATH=partitions/$HOST/$NAME
    echo Creating $HOST/${NAME}-${SERVERSUFFIX}
    if [ -e $PART_PATH ]; then
      echo =============================
      echo Error: $PART_PATH already exists
      echo =============================
      exit 1
    fi
    mkdir -p $PART_PATH

    # create redis.conf file
    CONFIG=${PART_PATH}/redis.conf
    ln -s $PWD/$REDISVERSION/redis-server \
          ${PART_PATH}/${NAME}-${SERVERSUFFIX}
    echo daemonize yes                          > $CONFIG
    echo pidfile ${PWD}/${PART_PATH}/redis.pid >> $CONFIG
    echo port $PORT                            >> $CONFIG
    echo timeout 300                           >> $CONFIG
    echo loglevel notice                       >> $CONFIG
    echo logfile redis.log                     >> $CONFIG
    echo databases 1                           >> $CONFIG
    if [ "_${APPENDONLY}" = "_yes" ]; then
      # Journalled Save
      echo appendonly yes                      >> $CONFIG
      echo appendfsync everysec                >> $CONFIG
    else
      # Async Save
      # after 5 seconds if at least one key changed
      # echo save $REDIS_SAVE_SEC 1 >> $CONFIG
      echo save 1 1                            >> $CONFIG
      echo appendonly no                       >> $CONFIG
      echo rdbcompression yes                  >> $CONFIG
      echo dbfilename dump.rdb                 >> $CONFIG
    fi
    echo dir ./                                >> $CONFIG
    echo glueoutputbuf yes                     >> $CONFIG
    echo shareobjects no                       >> $CONFIG

    # create start.sh file
    echo cd \"${PWD}/${PART_PATH}\" > ${PART_PATH}/start.sh
    echo echo -n Starting ${NAME}-${SERVERSUFFIX}\" \"  >> ${PART_PATH}/start.sh
    echo ./${NAME}-${SERVERSUFFIX} redis.conf 1\> access.log 2\> error.log \& >> ${PART_PATH}/start.sh
    # echo ps -ef\|grep \$\$\|grep ${NAME}-${SERVERSUFFIX}\|grep -v \$0\|awk \'{ print \$2 }\' \> redis.pid >> ${PART_PATH}/start.sh
    # echo if ! [ -r redis.pid ]\; then sleep 1    >> ${PART_PATH}/start.sh
    # echo elif ! [ -r redis.pid ]\; then sleep 3  >> ${PART_PATH}/start.sh
    # echo elif ! [ -r redis.pid ]\; then sleep 10 >> ${PART_PATH}/start.sh
    # echo fi                                      >> ${PART_PATH}/start.sh
    echo echo pid: \`cat redis.pid\`            >> ${PART_PATH}/start.sh


    # create stop.sh file
    echo cd \"${PWD}/${PART_PATH}\" > ${PART_PATH}/stop.sh
    echo echo Stopping ${NAME}-${SERVERSUFFIX} pid: \`cat redis.pid\` >> ${PART_PATH}/stop.sh
    echo echo SHUTDOWN \| nc $HOST $PORT >> ${PART_PATH}/stop.sh
    echo rm -f redis.pid >> ${PART_PATH}/stop.sh

    # create appendonly bg rewrite script
    if [ "_$APPENDONLY" = "_yes" ]; then
      # create appendonly save
      AOFRC=partitions/$HOST/appendonly/appendonly.sh
      if ! [ -r $AOFRC ]; then
        mkdir -p partitions/$HOST/appendonly
        echo \#!`which dash` > $AOFRC
        echo echo \$\$ \> ${PWD}/partitions/$HOST/appendonly/appendonly.pid >> $AOFRC
      fi
      echo sleep $REDIS_SAVE_SEC                                        >> $AOFRC
      echo ${PWD}/${REDISVERSION}/redis-cli -p $PORT Bgrewriteaof      >> $AOFRC
    fi

    # create monitrc
    MONITRC=partitions/$HOST/monit/monitrc
    if ! [ -r $MONITRC ]; then
      mkdir -p partitions/$HOST/monit
      echo set daemon $MONIT_DAEMON_SEC                                 > $MONITRC
      echo set httpd port 4280                                         >> $MONITRC
      echo allow localhost                                             >> $MONITRC
      echo set logfile ${PWD}/partitions/${HOST}/monit/logfile         >> $MONITRC
     #echo set mailserver localhost                                    >> $MONITRC
     #echo set alert foo@bar.baz                                       >> $MONITRC
      echo >> $MONITRC
      echo check system localhost                                      >> $MONITRC
      echo if loadavg \(1min\) \> 4 then alert                         >> $MONITRC
      echo if loadavg \(5min\) \> 2 then alert                         >> $MONITRC
      echo if memory usage \> 50% then alert                           >> $MONITRC
      echo if cpu usage \(user\) \> 90% then alert                     >> $MONITRC
      echo if cpu usage \(system\) \> 70% then alert                   >> $MONITRC
      echo >> $MONITRC
 
      chmod 700 $MONITRC
    fi

    echo check process ${NAME}                                         >> $MONITRC 
    echo with pidfile \"${PWD}/${PART_PATH}/redis.pid\"                >> $MONITRC
    echo start program = \"`which bash` ${PWD}/${PART_PATH}/start.sh\" >> $MONITRC
    echo stop program = \"`which bash` ${PWD}/${PART_PATH}/stop.sh\"   >> $MONITRC
    echo if failed host localhost port $PORT then restart              >> $MONITRC
    echo if 5 restarts within 5 cycles then timeout                    >> $MONITRC
    echo >> $MONITRC

  fi # data|status
done

exit
