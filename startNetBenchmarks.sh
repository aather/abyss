#!/bin/bash
DIR=/usr/share/abyss
#DIR=/home/abyssagentsprod/abyss

killall(){
for PID in $PIDLIST
 do
        kill -9 $PID 2>/dev/null
 done
exit
}

trap killall HUP INT QUIT KILL TERM USR1 USR2 EXIT

# Start Net latency, throughput and memcached RPS Benchmarks
cd $DIR/test-suites/net-tests/
 nohup ./netTPS.pl &                    # Run network latency tests nonstop. Low net overhead!
 PIDLIST="$PIDLIST $!"
 nohup ./pingRTT.pl &
 PIDLIST="$PIDLIST $!" 
while :			
do					
 nohup ./sysnet.pl &
 PIDLIST="$PIDLIST $!"
 nohup ./netBW.pl             		# Start Net throughput test while latency and TPS tests are running in background
 pkill sysnet.pl 		
 nohup ./sysmemRTT.pl &
 nohup ./memcachedRTT.pl		# When Net throughput test ends start memcache test
 pkill sysmemRTT.pl
done

