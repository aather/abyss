#!/bin/bash

# check if it is centOS, then install nc package 
version=`uname -r`
if [[ $version  =~ "3.2" ]] || [[ $version =~ "2.6" ]]
then
   sudo yum install -y nc
fi

# Uncomment agents that you would like to start

# Agent to monitor system stats: cpu, io, disk, net, mem
cd monitor
nohup ./loop-systats.sh &
cd ..

# Agent to monitor Storage IO latencies
if [[ $version  =~ "2.6" ]]
then
  echo "perf is not available on CentOS 2.6. iolatency agent is not started\n"
else
 cd SNIFFER
 nohup ./loop-iolatency.sh &
 cd ..
fi

# Agent to monitor low level tcp stats: per connection RTT, Throughput, Retransmit, Congestion, etc..
version=`uname -r`
if [[ $version  =~ "3.2" ]] || [[ $version =~ "2.6" ]]
then
    echo "Ubuntu Precise and CentOS do not have required python libraries. Sniffer.pl agent is not started\n";
else
   cd SNIFFER
   nohup ./loop-tcpstats.sh &
   cd ..
fi

# Agent to monitor Application stats via JMX port. Only Cassandra agent is available. kafka, elasticsearch and 
# tomcat are planned
if [ -d "/apps/nfcassandra_server" ] 
then
 cd APPS/CASSANDRA
 nohup ./loop-cassandra.sh &
 cd ../..
fi
