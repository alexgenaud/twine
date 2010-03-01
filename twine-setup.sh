#~/bin/bash

REDISVERSION=redis-1.2.2
SERVERSUFFIX=redis-server-1.2.2

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
      echo status line
      LINETYPE=status
      NAME=`echo $LINE |sed s:=.*::`
      HOST=`echo $LINE |awk '{ print $2 }'`
      PORT=`echo $LINE |awk '{ print $3 }'`
        DB=`echo $LINE |awk '{ print $4 }'`
    else
      echo NONESENSE
    fi # data or status line

    echo Creating $NAME on $PORT
    if [ -e partitions/$NAME ]; then
      rm -rf partitions
      echo =============================
      echo Error: partitions/$NAME already exists
      echo =============================
      exit 1
    fi
    mkdir -p partitions/$NAME
    CONFIG=partitions/${NAME}/redis.conf
    ln -s $PWD/$REDISVERSION/redis-server \
          partitions/${NAME}/${NAME}-$SERVERSUFFIX
    echo port $PORT            > $CONFIG
    echo timeout 300          >> $CONFIG
    echo dir ./               >> $CONFIG
    echo loglevel notice      >> $CONFIG
    echo logfile redis.log    >> $CONFIG
    echo databases 2          >> $CONFIG
    echo appendonly yes       >> $CONFIG
    echo appendfsync everysec >> $CONFIG
    echo glueoutputbuf yes    >> $CONFIG
    echo shareobjects no      >> $CONFIG

  fi # data|status
done

exit
