#!/bin/bash

# You need to provide peer host address. Make sure peer host has netserver and memcached running on open ports
# $sudo netserver -p $port
# $sudo memcached -p $port -u nobody -c 32768 -o slab_reassign slab_automove -I 2m -m 59187 -d -l 0.0.0.0

if [ "$#" -ne 1 ]; then
    echo "Please provide peer host public address.
    exit 1
fi

$peer = $1

if [ "$#" -ne 1 ]; then
    echo "Please provide netserver process port number on peer host"
    exit 1
fi

$netport = $1

if [ "$#" -ne 1 ]; then
    echo "Please provide memcached process port number on peer host"
    exit 1
fi

$memport = $1


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
cd TEST-SUITES/NET-TESTS
while :
do
 nohup ./netBW.pl $peer $netport            # Network throughput tests
 nohup ./netTPS.pl $peer $netport&       # Next two network latency tests starts together
 nohup ./pingRTT.pl $peer 
 nohup ./memcachedRTT.pl $peer $memport     # memcache RPS test
done

