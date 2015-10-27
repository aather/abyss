#!/bin/bash

DIR=`pwd`

killall()
{
 kill  `pgrep systats.pl`   2>/dev/null
 kill  `pgrep tcpstats.pl`  2>/dev/null
 kill  `pgrep iolatency.pl` 2>/dev/null
 kill  `ps -elf|grep CLOUDSTAT|grep -v grep |awk '{print $4}'` 2>/dev/null

for PID in $PIDLIST
 do
        kill -9 $PID 2>/dev/null
 done
exit
}

trap killall HUP INT QUIT KILL TERM USR1 USR2 EXIT

# Agent to monitor system stats: cpu, io, disk, net, mem
cd $DIR/monitor
nohup ./loop-systats.sh &
PIDLIST="$PIDLIST $!"
cd ..

# Agent to monitor Storage IO latencies
# check if perf is installed
if [ -f "/usr/bin/perf" ] 
then
 cd $DIR/sniffer/IO
 nohup ./loop-iolatency.sh &
 PIDLIST="$PIDLIST $!"
else
  echo "perf is not available. iolatency agent is not started"
fi

# Agent to monitor low level tcp stats: per connection RTT, Throughput, Retransmit, Congestion, etc..
#if [ -f "/usr/bin/make" ] 
#then
#   cd $DIR/sniffer/NET
#   nohup ./loop-tcpstats.sh &
#   PIDLIST="$PIDLIST $!"
#fi

# Start Net latency, throughput and memcached RPS Benchmarks
cd $DIR/test-suites/net-tests/
while :
do
 nohup ./netTPS.pl &       		# Run network latency tests nonstop. Low net overhead!
 PIDLIST="$PIDLIST $!"
 nohup ./pingRTT.pl & 
 PIDLIST="$PIDLIST $!"
 nohup ./netBW.pl             		# Start Network throughput test
 nohup ./memcachedRTT.pl		# When Net throughput test ends start memcache test
done

