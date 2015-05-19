#!/bin/bash

# check if it is centOS, then install netcat 'nc' package. It is not installed on CentOS instances 
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
if [ -f "/usr/bin/perf" ] 
then
 cd sniffer
 nohup ./loop-iolatency.sh &
 cd ..
else
  echo "perf is not available. iolatency agent is not started"
fi

# Agent to monitor low level tcp stats: per connection RTT, Throughput, Retransmit, Congestion, etc..
if [ -f "/usr/bin/make" ] 
then
   cd sniffer
   nohup ./loop-tcpstats.sh &
   cd ..
fi

# Agent to monitor Application stats via JMX port. Only Cassandra agent is available. kafka, elasticsearch and 
# tomcat are planned
if [ -d "/apps/nfcassandra_server" ] 
then
 cd app/cassandra
 nohup ./loop-cassandra.sh &
 cd ../..
fi

