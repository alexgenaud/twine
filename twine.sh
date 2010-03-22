#~/bin/bash

REDISVERSION=redis-1.2.5
CMD=
KEY=
VAL=

if [ `echo $1 | grep -Ei "^(randomkey)$" | wc -l` = 1 ]; then
  CMD=$1
elif [ `echo $1 | grep -Ei \
       "^(exists|dlel|type|get|expire|ttl|getset|incr|decr|llen)$"\
       | wc -l` = 1 ]; then
  CMD=$1
  KEY=$2
elif [ `echo $1 | grep -Ei \
        "(set|incrby|decrby|rpush|lpush)"\
        | wc -l` = 1 ]; then
  CMD=$1
  KEY=$2
  VAL=$3
else
  echo unsupported command
  exit 1
fi 


HASH=`sh twine-hash.sh $KEY 1234568`


# lookup the hash mod number in status node
# to get the host/ip, port, and database of
# the appropriate master for this hash val
HOST=localhost
PORT=4200
DB=0

$REDISVERSION/redis-cli -h $HOST -p $PORT -n $DB $CMD $KEY $VAL

