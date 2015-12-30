![Abyss](abyss.jpg)

Abyss is used to monitor application and server performance. To estimate resource demand of complex workload, it is essential to have access to low level profiling data captured at proper granularity. Abyss is designed to understand application characteristics by measuring relevent metrics across full software stack. Correlation is then performed to identify resource constraints limiting application performance. Abyss toolset provides access to low level profiling data captured at higher resolution. 
## Abyss Design

Abyss agents run on a server or a cloud instance to capture application and system level metrics and periodically push them to a graphite server (Support for influxdb and Elastic Search are planned).

Ready to use dashboards are created using Grafana to visualize metrics and to perform data correlation.

Abyss is consist of three components:

- **Agents:** Agents run on the instance being monitored and are written using perl, python and C.
  - **App:** App agents capture java application and jvm metrics via JMX port on localhost. Cassandra, kafka and tomcat agents are available. 
  - **System:** System agent captures system metrics: cpu, mem, net, io, NFS
  - **Sniffer:** Sniffer agents captures low level per connection tcp metrics and IO latency metrics using perf and kernel module
  - **Benchmark:** benchmarking agents are used to automate the process of running  network and IO benchmarks. Agents also collects relevent benchmark and system level metrics  
- **Graphite Server:** Agents periodically (default: every 5 seconds) ship metrics to graphite server on the network. 
- **Visualization:** Once sufficient metrics (15-30 minutes) are collected, Grafana dashboards are used to visualize it. Ready to use Dashboards are available. 

## Abyss Config 
All config options for abyss agents are provided in a single file: **env.pl**. There are separate section for server running in AWS cloud and datacenter. Few options are listed below: 

 - **region-**           Sets Amazon Region: us-east-1, us-west-1..
 - **host-**             Sets hostname or Amazon cloud instance id: i-c3a4e33d
 - **server-**           Sets Server name or Application cluster name
 - **carbon_server-**    Sets hostname of graphite carbon server for storing metrics
 - **carbon_port-**      Sets Port where graphite carbon server is listening
 - **interval-**         Sets metrics collection granularity
 - **iterations-**	 Sets number of benchmark iterations to perform

You can run application and system agents running script below on the system or cloud instance being monitored

$./startMonitoring

This will start accumulating metrics in to graphite server. Wait for **15-30** minutes to have sufficient metrics displayed on dashboard and then enter URL of graphite server. 

http://hostname-or-IPAddr-of-graphite-server:7410/


To run network Benchmark set environment variables in **env.pl** file to set hostname of peer host running netserver and memcached servers. Istall and start netserver and memcached server with options below:
- netserver: sudo netserver -p 7420
- memcached: $sudo memcached -p 7425 -u nobody -c 32768 -o slab_reassign slab_automove -I 2m -m 59187 -d -l 0.0.0
- peer =  "hostname-or-IPADDR-of-peer-running-netserver-memcached"

Start benchmark agents:
$./startNetBenchmark 

## Abyss In Action

![Abyss](abyss.jpg)
![Abyss](bench.png)
![Abyss](app.png)

## Metrics
 List of metrics collected by abyss toolset:

- System Metrics: 
    - **cpu:**  cpu and percpu utilization: idle, sys, usr, intr, cpu load: runnable and blocked threads, context switches
    - **memory:**  free (unused), free (cached) and used memory
    - **network:** system-wide Network throughput, pps, tcp segments, tcp timeouts, per connection stats: Network throughput, Latency (RTT), retransmit, packet size, ssthresh, cwnd, rwnd, read/write queue size
    - **io:** system-wide IO throughput, IOPS, IO latency and IO size

- Application Metrics:
  - **cassandra**
    - coordinator and C* column family read and write latency
    - IOPS coordinator and C* column family read and write Ops
    - Pending Tasks: Type of Tasks pending completion: compaction, hintedhandoff, readstage, etc..
    - compaction: total bytes compacted, memtable size and memtable switch rate
    - sstable stats, sstable cached in memory, sstable sizes and sstable counts
    - java memory Heap and non heap usage
    - GC garbage collection duration

- Benchmark Metrics
    - **ping -A:** measure net latency. Adoptive ping that adopts to RTT. There can only be one unanswered probe pending at any time. Lower value (RTT) is better representing lower network latency
    - **netperf:** measure net latency: TCP request response test with request/response payload of 1 byte. There can be only one transaction pending at any time. Higher number of transactions (TPS) is better representing lower network latency
    - **netperf:** measure net throughput. TCP throughput test with message size equals to the default socket buffer size, Amazon AWS cloud instances are throttled for outbound traffic. This test validates if the instance is achieving amazon advertise instance network bandwidth limit. Higher number is better.
    - **memcache:** measure net latency: Open source memcached client "mcblaster" is used to warm up the memcached server cache with 2 Million 100 bytes records. mcblaster client then performs 10k, 20k, 30k,... 80k gets/sec transactions to measure latencies. At the end of test, transactions completed within 1-10 ms are bucketed in 1ms increments. Tests showing higher number of gets operations in low latency buckets is better. To measure the impact of high rate get/second request, ping and netperf latency tests were kept running during the memcache testing.

To interpret benchmark visualization correctly, it is important to understand how data points (metrics) in the graph are generated:
  - For ping and netperf tests, I calculated min, max, 95th and 99th%ile on latency and throughput values printed during tests and then published them as metric. That means, every data point in the graph represents a single test result. Each test ran for 5-10 seconds
  - For memcached tests, I use the name/value of the bucket as a metric printed after the test ends. Each test ran for 10 seconds. Every data point in the graph represent a single test result. For memcached tests, "gets" RPS of 70k were used to measure its impact on overall Network latency.

## Future Enhancements
- Web browser interface instead of config files to start and control metric collection
- Support for new Applications
- Support for low level kernel metrics collected using: perf, ftrace, systemtap, sysdig  
- Support influxDB and ElasticSearch as a backend datastore
- Support for collecting time based java and system stacktraces using perf and accumulating it into ElasticSearch, influxDb  or Graphite for visualization using Brenden Gregg's Flame Graph. With support for frame pointer fix in openJDK and OracleJDK and java perf-agent integration, it is possible to have full stack analysis by collecting stack traces with Java (JIT), JVM, libc, and kernel routines. 

## Disclaimer
Use it at your own risk. Tested on Ubuntu Trusty only.  

## License

Licensed under the Apache License, Version 2.0 (the “License”); you may not use this file except in compliance with the License. You may obtain a copy of the License at

[http://www.apache.org/licenses/LICENSE-2.0](http://www.apache.org/licenses/LICENSE-2.0)

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an “AS IS” BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.
