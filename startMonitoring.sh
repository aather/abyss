#!/bin/bash

killall()
{
 kill  `pgrep systats.pl`   2>/dev/null
 kill  `pgrep tcpstats.pl`  2>/dev/null
 kill  `pgrep iolatency.pl` 2>/dev/null
 kill  `pgrep cassandra.pl` 2>/dev/null
 kill  `ps -elf|grep CLOUDSTAT|grep -v grep |awk '{print $4}'` 2>/dev/null

for PID in $PIDLIST
 do
        kill -9 $PID 2>/dev/null
 done
exit
}

trap "killall" HUP INT QUIT KILL TERM USR1 USR2 EXIT

# check if it is centOS, then install netcat 'nc' package. It is not installed on CentOS instances 
if [ -f "/usr/bin/yum" ] 
then
   sudo yum install -y nc
fi

# Agent to monitor system stats: cpu, io, disk, net, mem
cd monitor
nohup ./loop-systats.sh &
PIDLIST="$PIDLIST $!"
cd ..

# Agent to monitor Storage IO latencies
# check if perf is installed
if [ -f "/usr/bin/perf" ] 
then
 cd sniffer
 nohup ./loop-iolatency.sh &
 PIDLIST="$PIDLIST $!"
 cd ..
else
  echo "perf is not available. iolatency agent is not started"
fi

# Agent to monitor low level tcp stats: per connection RTT, Throughput, Retransmit, Congestion, etc..
if [ -f "/usr/bin/make" ] 
then
   cd sniffer
   nohup ./loop-tcpstats.sh &
   PIDLIST="$PIDLIST $!"
   cd ..
fi

# Agent to monitor Application stats via JMX port. Only Cassandra agent is available. kafka, elasticsearch and 
# tomcat are planned
if [ -d "/apps/nfcassandra_server" ] 
then
 cd app/cassandra
 nohup ./loop-cassandra.sh &
 PIDLIST="$PIDLIST $!"
 cd ../..
fi

wait
