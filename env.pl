#! /usr/bin/perl 

# Abyss expect ingress network traffic to be allowed on the following ports. Default ports:
#  graphite carbon server:  			7405, 7406, 7407
#  netserver (net benchmark):  			7420, 7421
#  memcached (RPS benchmark): 			7425
#  ElasticSearch (saves dashboards): 		7410, 7411
#  cloudstat_port (fetches tcp stats):		7415 
#  apache2:			  		80
#  ping RTT:					ICMP traffic should be allowed

# Config options

if(!defined $ENV{'EC2_REGION'}) {  	     	# Sets Amazon Region: us-east-1, us-west-1..
 $region = `curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone`;
}

if(!defined $ENV{'EC2_INSTANCE_ID'}){		# Sets Amazon cloud instance id: i-c3a4e33d		
 $host = `curl -s http://169.254.169.254/latest/meta-data/instance-id`;
}

if(defined $ENV{'NETFLIX_APP'}) {		# Sets Server name or Application cluster name
 $server = "cluster.$ENV{'NETFLIX_APP'}";     	# Sets Server name or Application cluster name 
} else {
 $server = "cluster.cloudperf";			# Sets to match your application name
}

if(!defined $ENV{'NETFLIX_ENVIRONMENT'}){ 	# graphite server hostname or IP address 
 $carbon_server = "my-graphite-server.$region.amazonaws.com";	
} else {
 $carbon_server = "abyss.$ENV{'EC2_REGION'}.$ENV{'NETFLIX_ENVIRONMENT'}.netflix.net";
}

if(!defined $ENV{'EC2_LOCAL_IPV4'}) { 		# Private IP Address of Amazon instance  
 $localIP = `curl -s http://169.254.169.254/latest/meta-data/local-ipv4`          

if(!defined $ENV{'EC2_PUBLIC_IPV4'}) { 		# Public IP Address of Amazon instance  
 $localIP = `curl -s http://169.254.169.254/latest/meta-data/public-ipv4`          

cloudstat_port = "7415";                     	# cloudstat python server port that reads low level tcp stats

if(!defined $ENV{'NETFLIX_ENVIRONMENT'}){       # graphite server hostname or IP address
 $carbon_port = 7405;				# Port where graphite carbon server is running
} else {
 $carbon_port = 7001;
}

$interval = 5;					# Sets sample interval

#-------Benchmark Environment Variables ---------
# For network latency and throughput benchmark, You need to set peer hostname or IP address and port numbers 

$peer =  "ec2-instance-name-here";		# peer host running netserver and memcached daemons
$net_cport = 7420;				# netserver data port on peer host for network benchmark
$net_dport = 7421;				# netserver control port on peer host for network benchmark

# For network RPS benchmark with memcache, peer host should be running memcached process on port below:
$mem_port = 7425;

$RPS = 50000;					# Sets RPS rate for memcached benchmark
$iterations = 500;				# Set number of benchmark test iterations
