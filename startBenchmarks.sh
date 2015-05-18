#!/bin/bash

# check if it is centOS, then install netcat 'nc' package 
version=`uname -r`
if [ -f "/usr/bin/yum" ]
then
   sudo yum install -y nc
fi

# Agent to monitor system stats: cpu, io, disk, net, mem
cd monitor
nohup ./loop-systats.sh &
cd ..

# Agent to monitor Storage IO latencies
# check if perf is installed
if [ -f "/usr/bin/perf" ] then
 cd sniffer
 nohup ./loop-iolatency.sh &
else
  echo "perf is not available. iolatency agent is not started"
fi

# Agent to monitor low level tcp stats: per connection RTT, Throughput, Retransmit, Congestion, etc..
if [ -f "/usr/bin/make" ] then
   cd sniffer
   nohup ./loop-tcpstats.sh &
   cd ..
fi

#Start net latency and throughput tests one by one and let them run forever
cd test-suites/net-tests
while :
do
 nohup ./netBW.pl             		# Network throughput tests
 nohup ./netTPS.pl &       		# Next two network latency tests starts together
 nohup ./pingRTT.pl 
 nohup ./memcachedRTT.pl		# memcache RPS test
done

