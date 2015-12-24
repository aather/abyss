#! /usr/bin/perl 

# Abyss agents collect system and application metrics from monitored server 
# and ship it to graphite server. grafana Dashboards are then used to graph metrics
#
# Abyss expect ingress network traffic to be opened on the following ports. 
# ----------Default ports----------
#  graphite carbon server:  			7405, 7406, 7407
#  grafana server:				7401
#  cloudstat_port (tcp sniffer agent):		7415 
#  apache2:			  		80
#
#  ----- For running benchmarks ----
#  netserver (net benchmark):  			7420, 7421, 7422
#  memcached (RPS benchmark): 			7425
#  ping RTT:					ICMP traffic should be allowed
#
# --- Environment Variables exported to all agents

$carbon_server = "IP-ADDR-OF-GRAPHITE-SERVER"; # graphite server name or IP address
$carbon_port = 7405;                               # graphite carbon server port
$cloudstat_port = "7415";                          # sniffer agent port
$interval = 5;                                     # Sets agents sample interval
#-----------------------
# Uncomment if running abyss agents on Amazon cloud instance
#
$region = `curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone`;
$host = `curl -s http://169.254.169.254/latest/meta-data/instance-id`;
$localIP = `curl -s http://169.254.169.254/latest/meta-data/local-ipv4`;          
$publicIP = `curl -s http://169.254.169.254/latest/meta-data/public-ipv4`;          
$server = "cluster.myapp";		# Metrics are accumulated under app name
					# e.g: cluster.myapp. Change "myapp" to your app name.

# Uncomment if running agents on system in data center or VirtualBox VM. 
#$host = "MYHOST";
#$localIP = "IP ADDRESS OF MYHOST";      # IP address of VM running agents to capture metrics 
#$publicIP = "IP ADDRESS OF MYHOST";     # Same as above
#$server = "cluster.myapp";              # Metrics are accumulated under application name
                                         # e.g: myapp. Change it to match your app name
$interval = 5;				 # Sets sample interval

#-------Benchmark Environment Variables ---------
#
# To run benchmark, you need to setup peer host and run netserver and memcached server
# No need to install abyss package on peer running netserver and memcached server
# Start netserver and memcached server on peer host as follows:
# netserver: $sudo netserver -p 7420
# memcached: $sudo memcached -p 7425 -u nobody -c 32768 -o slab_reassign slab_automove -I 2m -m 59187 -d -l 0.0.0
$peer =  "IPADDR-OF-MEMCACHED-AND-NETSERVER";   # peer host running netserver and memcached daemons
$net_dport = 7420;				# netserver data port on peer host for network benchmark
$net_cport = 7421;				# netserver control port on peer host for net throughput benchmark
$net_rport = 7422;				# netserver control port on peer host for net latency benchmark
$mem_port  = 7425;				# memcached port
# Sets RPS rate for memcached benchmark. To specify fixed RPS rate, specify a single value: ('50000');
@RPS = (30000,40000,50000,60000,70000,80000,90000,100000);
$iterations = 10;				# Sets number of benchmark test iterations

1:
