#!/bin/bash
DIR=/usr/share/abyss
cd $DIR/test-suites/net-tests/memcached/
while :			
do					
 nohup ./memcachedRTT.pl
done

