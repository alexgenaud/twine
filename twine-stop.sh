ps ax | grep redis-server | grep -v grep |\
        sed "s: [a-z].*::" | sed "s:^:kill -9 :" | sh

