#! /usr/bin/perl 

# Abyss expect ingress network traffic to be allowed on the following ports. Default ports:
#  graphite carbon server:  			7405, 7406, 7407
#  elasticSearch (saves dashboards): 		7410, 7411
#  cloudstat_port (fetches tcp stats):		7415 
#  apache2:			  		80
#
#  ----- For running benchmarks ----
#
#  netserver (net benchmark):  			7420, 7421
#  memcached (RPS benchmark): 			7425
#  ping RTT:					ICMP traffic should be allowed
#
# --- Environment Variables exported to all agents

$region = `curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone`;
$host = `curl -s http://169.254.169.254/latest/meta-data/instance-id`;
$localIP = `curl -s http://169.254.169.254/latest/meta-data/local-ipv4`;          
$publicIP = `curl -s http://169.254.169.254/latest/meta-data/public-ipv4`;          
$server = "cluster.cloudperf";				# Metrics are accumulated under application name
							# e.g: cloudperf. Change to match your application
$carbon_server = "graphiteserver.cloudperf.net";	# graphite server for storing metrics	
$carbon_port = 7405;					# Port where graphite carbon server is running
$cloudstat_port = "7415";                     		# python server port. It reads low level tcp stats
$interval = 5;						# Sets sample interval

#-------Benchmark Environment Variables ---------
# To run benchmark, you need to set peer host and run netserver and memcached on the matching ports
# netserver: sudo netserver -p 7420
# memcached: $sudo memcached -p 7425 -u nobody -c 32768 -o slab_reassign slab_automove -I 2m -m 59187 -d -l 0.0.0

$peer =  "ec2-instance-name-here";		# peer host running netserver and memcached daemons
$net_dport = 7420;				# netserver data port on peer host for network benchmark
$net_cport = 7421;				# netserver control port on peer host for network benchmark
$mem_port  = 7425;				# memcached port
$RPS = 50000;					# Sets RPS rate for memcached benchmark
$iterations = 500;				# Sets number of benchmark test iterations
