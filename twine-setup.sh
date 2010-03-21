#~/bin/bash

REDISVERSION=redis-1.2.5
SERVERSUFFIX=redis-server-1.2.5
USE_HOST=$1

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
      rm -rf partitions
      echo =============================
      echo Error: $PART_PATH already exists
      echo =============================
      exit 1
    fi
    mkdir -p $PART_PATH

    # create redis.conf file
    CONFIG=${PART_PATH}/redis.conf
    ln -s $PWD/$REDISVERSION/redis-server \
          ${PART_PATH}/${NAME}-$SERVERSUFFIX
    echo port $PORT            > $CONFIG
    echo timeout 300          >> $CONFIG
    echo dir ./               >> $CONFIG
    echo loglevel notice      >> $CONFIG
    echo logfile redis.log    >> $CONFIG
    echo databases 1          >> $CONFIG
    # Async Save
    # after one minute if at least one key changed
    echo save 60 1            >> $CONFIG
    echo rdbcompression yes   >> $CONFIG
    echo dbfilename dump.rdb  >> $CONFIG
    echo dir ./               >> $CONFIG
    # Journalled Save
    echo appendonly no        >> $CONFIG
    echo appendfsync everysec >> $CONFIG
    echo glueoutputbuf yes    >> $CONFIG
    echo shareobjects no      >> $CONFIG

    # create start.sh file
    echo cd \"${PWD}/${PART_PATH}\" > ${PART_PATH}/start.sh
    echo echo -n Starting ${NAME}-${SERVERSUFFIX}\" \"  >> ${PART_PATH}/start.sh
    echo ./${NAME}-$SERVERSUFFIX redis.conf 1\> access.log 2\> error.log \& >> ${PART_PATH}/start.sh
    echo ps -ef \| grep \$\$ \| grep ${NAME}-$SERVERSUFFIX \| grep -v \$0 \| grep -v grep \| awk \'\{ print \$2 \}\' \> redis.pid >> ${PART_PATH}/start.sh
    echo echo pid: \`cat redis.pid\` >> ${PART_PATH}/start.sh

    # create stop.sh file
    echo cd \"${PWD}/${PART_PATH}\" > ${PART_PATH}/stop.sh
    echo echo Stopping ${NAME}-${SERVERSUFFIX} pid: \`cat redis.pid\` >> ${PART_PATH}/stop.sh
    echo echo SHUTDOWN \| nc $HOST $PORT >> ${PART_PATH}/stop.sh
    echo rm -f redis.pid >> ${PART_PATH}/stop.sh

  fi # data|status
done

exit
