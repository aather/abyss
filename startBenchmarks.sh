#!/bin/bash

# You need to provide peer host address. Make sure peer host running netserver and memcached server
# $sudo netserver -p 7101
# $sudo memcached -p 7002 -u nobody -c 32768 -o slab_reassign slab_automove -I 2m -m 59187 -d -l 0.0.0.0

if [ "$#" -ne 1 ]; then
    echo "Please provide peer host public address. e.g: ec2-54-92-215-166.compute-1.amazonaws.com"
    echo ""
    echo "Make sure peer is running netserver on port 7101"
    echo "peer should also have memcached installed and running on port 7002"
    echo ""
    exit 1
fi
echo "peer hosts: $1"

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
 nohup ./netBW.pl $1            # Network throughput tests
 nohup ./netTPS.pl $1 &         # Next two network latency tests starts together
 nohup ./pingRTT.pl $1
 nohup ./memcachedRTT.pl $1     # memcache RPS test
done

