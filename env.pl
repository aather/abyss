#! /usr/bin/perl 
#
#  Abyss agents collect system and application metrics from 
#  monitored server and ship it to graphite server on the network. 
#  grafana Dashboards are then used to query and graph metrics
#
#  In order for abyss agents to push metrics to graphite server,
#  make sure to open ingress network traffic to graphite server 
#  port. Abyss agents also require grafana and apache services
#  to be hosted on your network. 
#  You can setup a server side of Abyss quickly for testing
#  by running "graphite-setup/graphite-setup" script provided.
#  Script sets up all three services: graphite, grafana and apache
#  that Abyss agents use for storing and graphing metrics.
#
#  Following ports are used as default, You can change it 
#  to fit your network environment
#
#  graphite carbon server ports:		7405, 7406, 7407
#  grafana server port:				7410
#  cloudstat_port (tcp sniffer agent):		7415 
#  apache2					80 
#
#  There are agents are provided to automate IO and 
#  network benchmarking. To run network benchmarks, 
#  you need to install netserver, webserver 
#  and/or memcached packages on a peer host. In order 
#  for benchmark agents to connect to these services on
#  peer host, you need to open following network ports:
#
#  netserver (Throughput benchmark): 		7420, 7421
#  netserver (Net Latency benchmark):		7422
#  memcached (RPS benchmark): 			7425
#  webserver (RPS benchmark) 			7430
#  ping RTT (Net Latency benchmark):		allow ICMP  
#
# -- Environment Variables exported to abyss agents --
#
#$carbon_server = "graphite ip or hostname"; 	   # graphite server
$carbon_server = "172.31.7.252";	 	   # graphite server
$carbon_port = 7405;                               # graphite carbon server port
$cloudstat_port = "7415";                          # sniffer agent port
$interval = 5;                                     # Sets agents sample interval
#
# Uncomment if running abyss agents on Amazon cloud instance
# aws instance metadata can be used to find: region, instance-id of the monitored server 
# Default: server running in amazon cloud
$region = `curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone`;
$host = `curl -s http://169.254.169.254/latest/meta-data/instance-id`;
$localIP = `curl -s http://169.254.169.254/latest/meta-data/local-ipv4`;          
$publicIP = `curl -s http://169.254.169.254/latest/meta-data/public-ipv4`;          
$server = "cluster.Netflix"; 		# Metrics are accumulated under app name
#					# e.g: cluster.Netfix. Change "Netflix" to your app name.
#
# Uncomment if running agents in data center or VirtualBox VM. 
# $host = "MYHOST";
# $localIP = "IP ADDRESS OF MYHOST";      # IP address of VM running agents to capture metrics 
# $publicIP = "IP ADDRESS OF MYHOST";     # Same as above
# $server = "cluster.Netflix";            # Metrics are accumulated under application name
#                                         # e.g: Netflix. Change it to match your app name
#
# Sampling Interval
$interval = 5;				 # Sets sample interval, default 5 second
#
# -- Additional Environment variables for Benchmark Agents --
#
# -- Network Benchmark --
# To run net benchmark, you may need to run netserver, memcached 
# and/or web servers on $peer host. Default ports for netserver, 
# memcache and webserver are: 7420, 7425, 7430 respectively.
# 
$peer =  "peer hostname or IP ";	# peer host running netserver and memcached daemons
$iterations = 10;                       # Sets number of benchmark test iterations
#
# netserver Tests
# start netserver on $peer 
# $sudo apt-get install -y netserver
# $sudo netserver -p 7420
#
$net_dport = 7420;			# abyss agent will use this netserver data port on peer
$net_cport = 7421;			# abyss agent will use this netserver control port on peer
$net_rport = 7422;			# abyss agent will use this netserver port for net latency test
#
# memcache Tests
# start memcached on $peer 
# $sudo apt-get install -y memcached
# $sudo memcached -p 7425 -u nobody -c 32768 -o slab_reassign slab_automove -I 2m -m 59187 -d -l 0.0.0.0
#
$mem_port  = 7425;			# abyss agent will use this memcached port on peer
$threads = 2;				# controls mcblaster threads for memcache test 
$connections = 1;			# controls mcblaster connections per thread
$payload = 50; 				# controls mcblaster payload in bytes for "gets"
@RPS = (100000,150000,200000)		# controls mcblaster RPS rates
#
# webserver Tests
# start nginx webserver on $peer 
# $sudo apt-get install -y nginx 
# Setup /etc/nginx/nginx.conf, /etc/nginx/conf.d/default.conf file to set nginx port and other options.  
# Sample nginx.conf and default.conf is provided. Just copy them to directories listed above. 
# start nginx: $sudo service nginx start
#
$webserver_port = 7430;			# nginx port
$wthreads =  4;    			# control wrt threads for webserver test 
@CONNECTIONS = (8,16,32,64);   		# Number of web connections to test nginx webserver 
$filename = "";				# default file to fetch
#
# -- IO Benchmark  Variables --
@filesystems=('ext4','xfs','zfs');	# Supported filesystems: ('xfs','ext4','zfs') to run tests.  
@devices=('xvdb','xvdc','xvdd');	# List of devices. For multiple devices, stripe volume is build
$mpt='mnt';				# Sets mount point
#
# FIO options for IO benchmark
@blocks=('4k','16k','32k','1m'); 	# List of IO size to test. 
$filesize='1g';				# file size.
$procs='2';				# Number of concurrent fio processes running.
$iodepth='2';				# Controls number of concurrent IO. Applies to direct IO test
$fadvise='1';				# Setting 0 will disable fadvise_hints: POSIX_FADV_(SEQUENTIAL|RANDOM)
$cachehit='zipf:1.1';			# Cacheit distribution to use for partial fs cache hit. other option: pareto:0.9
$percentread=60;			# percent of read IO for mixed IO tests
$percentwrite=40;			# percent of write IO for mixed IO tests
$end_fsync=1;				# Sync file contents when job exits
$fsync_on_close=0;			# sync file contents on close. end_fsync only does it at job ends
#
# Type of fio Tests interested in running
$iolatencytests=1;                      # default is enabled. Set to 0 to disable io latency tests via directIO path
$iodirecttests=1;                       # default is enabled. Set to 0 to disable IO read tests via directIO path
#------
$randreadtests=1;                       # default is enabled. Set to 0 to disable random read no-cache tests
$randwritetests=0;                      # Set to 1 to enable random write no-cache tests 
$randreadmmap=0;                        # Set to 1 to enable random read tests using mmap
$randwritemmap=0;                       # Set to 1 to enable random write tests using mmap
$randmixedtests=0;                      # Set to 1 to enable mixed random tests
$randmixedmmap=0;                       # Set to 1 to enable mixed random tests using mmap
#-----
$seqreadtests=0;                        # default is enabled. Set to 0 to disable sequential read tests
$seqwritetests=0;                       # Set to 1 to enable sequential write tests
$seqreadmmap=0;                         # Set to 1 to enable sequentail read tests using mmap
$seqwritemmap=0;                        # Set to 1 to enable sequentail write tests using mmap
$seqmixedtests=0;                       # Set to 1 to enable mixed sequential tests
$seqmixedmmap=0;                        # Set to 1 to enable mixed sequential tests using mmap
1;

