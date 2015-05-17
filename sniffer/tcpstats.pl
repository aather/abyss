#! /usr/bin/perl 

#use warnings;
use strict;

my @data = ();   # array to store metrics
my $now = `date +%s`;
my $env = $ENV{'NETFLIX_ENVIRONMENT'}; # test or prod
my $region = $ENV{'EC2_REGION'};
my $host = "$ENV{'EC2_INSTANCE_ID'}";  # ex: i-c3a4e33d 
my $server = "cluster.$ENV{'NETFLIX_APP'}";   # ex:  abcassandra_2
my $localIP = $ENV{'EC2_LOCAL_IPV4'};
my $publicIP =  $ENV{'EC2_PUBLIC_IPV4'};
my $carbon_server;
my @stats;
my @percentile;
my $interval = 5;
my $exit;
my $key1;
my $key2;
my $keyjoined;
my $value1;
my $value2;
my $value3;
my $value4;
my $value5;
my $value6;
my $value7;
my $value8;
my $value9;
my $value10;

if ( $env =~ /prod/) {
 $carbon_server = "abyss.$region.prod.netflix.net";
 }
else {
 $carbon_server = "abyss.$region.test.netflix.net";
 }

#compile and load kernel module tcp_prob_plus 

if (-e '.compiled') { 
   print "tcp_probe_plus module is already been compiled"; 
}
else {
   $exit = `make`;
   if (($? >> 8) == 1 ){ 
     print "\n failed to compile kernel module";
     exit;
   }  
   else {
     print "\n kernel module is compiled successfully";
    `touch .compiled`;
 }
}

# load kernel module tcp_probe_plus if it has not been loaded yet     
$exit = `/sbin/lsmod|grep tcp_prob`;
if (($? >> 8) == 1 ) { # if not loaded then load tcp_probe module 
  $exit = `sudo /sbin/insmod tcp_probe_plus.ko full=1 probetime=100 bufsize=8192`;
  if (($? >> 8) == 1 ) { # if failed exit
    print "\n exit: $exit";
    print "\nfailed to load tcp_probe module \n";
    exit;
  }
  else {
   print "\n tcp_probe module is loaded successfully\n"; 
   `sudo chmod 444 /proc/net/tcpprobe`
 }
}
else { 
  print "\n tcp_probe module is already loaded\n";
}

#----------python packages required------------#
if (-e '.pythonmodules') {
   print "python modules are already been installed";
}
else {
      # install required python packages
     $exit = `lsb_release -c`; 
     if ($exit =~ /trusty/) {
      `sudo mv /etc/apt/sources.list /etc/apt/sources.list-ORIG`;
      `sudo cp sources-trusty.list /etc/apt/sources.list`;
      `sudo apt-get update`;
      `sudo apt-get -y install python-pip`;
      `sudo pip install -U pip`;
      `sudo -H pip install Django==1.6.2`;
     `sudo mv /etc/apt/sources.list-ORIG /etc/apt/sources.list`;
     `touch .pythonmodules`;
     }
    elsif ($exit =~ /precise/) {
      `sudo mv /etc/apt/sources.list /etc/apt/sources.list-ORIG`;
      `sudo cp sources-precise.list /etc/apt/sources.list`;
      `sudo apt-get update`;
      `sudo apt-get -y install python-pip`;
      `sudo pip install -U pip`;
      `sudo -H pip install Django==1.6.2`;
     `sudo mv /etc/apt/sources.list-ORIG /etc/apt/sources.list`;
     `touch .pythonmodules`;
    }
   else { 
       print "\n please perform manual install of python required packages";
       exit;
   }
}
# Start the python server process 
# one thread reads from /proc/net/tcpprobe buffer for tcp traffic 
# and then insert flows into the queue
# nohup python manage.py runserver $localIP:7403
$exit = `/bin/ps -elf|grep manage.py |grep -v grep`;
if (($? >> 8) == 1 ) {
  system("python ./CLOUDSTAT/manage.py runserver $localIP:7403 &");
  if (($? >> 8) == 1 ) {
    print "\nfailed to start python server \n";
    exit;
  }
  else {
   print "\n python server is started successfully\n"; }
   sleep 2
 }
else { print "\n python server is already running\n"; }

# Other python server thread waits for client requests and return the 
# flows in JSON. Start the fetcher thread
$exit = `curl -s http://$localIP:7403/app/startThread/1/`;
if (($exit =~ /Thread is already running/) || ($exit =~ /Thread started/))
 {
         print "\n  fetcher thread started successfully\n";
 }
else {
        print "\n Problem starting fetcher thread\n";
        print "\n exit: $exit\n";
        exit;
   }

# Run at lowest priority possible to avoid competing for cpu cycles with the workload
#setpriority(0,$$,19);

# Open a connection to the carbon server where we will be pushing the metrics
open(GRAPHITE, "| nc -w 25 $carbon_server 7001") || die print "failed to send data: $!\n";

# Run at lowest priority possible to avoid competing for cpu cycles with the workload
#setpriority(0,$$,19);

while (1) {
   # python server will stop capturing after 30 seconds of inactivity. Make sure it is running
   #`curl -s http://$localIP:7403/app/startThread/1/`;
   open (SNIFFER, "curl -s http://$localIP:7403/app/startCapturing/|json_pp |")|| die print "failed to get data: $!\n";
   $now = `date +%s`;
   while (<SNIFFER>) {
    next if /^$/;
    s/\{//g;  # trim {
    s/\]//g;  # trim ]
    s/\[//g;  # trim [
    s/,//g;   # trim ,
    s/"//g;   # trim ""
    chop;  # chops off the last character. without arg chops off $_
    @stats = split ":";
    $key1 = $stats[2] if ($stats[0] =~ /Source/); # save source port
    $key2 = $stats[1].":".$stats[2] if ($stats[0] =~ /Destination/); # save both IP and destination port
    # Values that you want to graph
    $value1 = $stats[1] if $stats[0] =~ /SRTT/;
    $value2 = $stats[1] if $stats[0] =~ /RETRANSMIT/;
    $value3 = $stats[1] if $stats[0] =~ /CumulativeBytes/;
    $value4 = $stats[1] if $stats[0] =~ /SSTRESH/;
    $value5 = $stats[1] if $stats[0] =~ /LENGTH/;
    $value6 = $stats[1] if $stats[0] =~ /CWND/;
    $value7 = $stats[1] if $stats[0] =~ /RWND/;
    $value8 = $stats[1] if $stats[0] =~ /LOST/;
    $value9 = $stats[1] if $stats[0] =~ /WQUEUE/;
    $value10 = $stats[1] if $stats[0] =~ /RQUEUE/;

    $key2=~s/^\s+//; # Remove space in the begining
    $key2=~s/\./_/g; # change . into _ because of graphite
    my $keyjoined = join "-", $key1,$key2;
     push @data, "$server.$host.system.tcp.traffic.RTT.$keyjoined $value1 $now\n"; 
     push @data, "$server.$host.system.tcp.traffic.RETRANS.$keyjoined $value2 $now\n"; 
     push @data, "$server.$host.system.tcp.traffic.CumulativeBytes.$keyjoined $value3 $now\n"; 
     $value4 = 0 if $value4 =~ /2147483647/;
     push @data, "$server.$host.system.tcp.traffic.SSTRESH.$keyjoined $value4 $now\n"; 
     $value5 = 0 if $value5 =~ /65535/; # last sample of a connection
     push @data, "$server.$host.system.tcp.traffic.LENGTH.$keyjoined $value5 $now\n"; 
     push @data, "$server.$host.system.tcp.traffic.CWND.$keyjoined $value6 $now\n"; 
     push @data, "$server.$host.system.tcp.traffic.RWND.$keyjoined $value7 $now\n"; 
     push @data, "$server.$host.system.tcp.traffic.LOST.$keyjoined $value8 $now\n"; 
     push @data, "$server.$host.system.tcp.traffic.WQUEUE.$keyjoined $value9 $now\n"; 
     push @data, "$server.$host.system.tcp.traffic.RQUEUE.$keyjoined $value10 $now\n"; 
    #} 
  }
 close(SNIFFER);

# Ship Metrics to carbon server --- 
  #print @data; # For Testing only 
  #print "\n------\n"; # for Testing only
  print GRAPHITE  @data;  # Shipping the metrics to carbon server
  @data=();     # Initialize the array for next set of metrics

  sleep $interval;
}
