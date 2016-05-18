#! /usr/bin/perl 

#use warnings;
#use strict;
use Fcntl qw/:flock/;

open SELF, "< $0" or die ;
flock SELF, LOCK_EX | LOCK_NB  or die "Another instance of the same program is already running: $!";

require "../../env.pl";    			# Sets up common environment varilables for all agents


#setpriority(0,$$,19);                          # Uncomment if running script at a lower priority
						# from kernel and publish in json

#$SIG{INT} = \&signal_handler;
#$SIG{TERM} = \&signal_handler;

my @data = ();                                  # array to store metrics
my $now = `date +%s`;                           # metrics are sent with date stamp to graphite server

open(GRAPHITE, "| ../../common/nc -w 200 $carbon_server $carbon_port") || die "failed to send: $!\n";

# ------------------------------agent specific sub routines-------------------

my @stats;
my @percentile;
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
my $value11;
my $value12;
my $value13;

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
      `sudo pip install -U datautil`;
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
      `sudo pip install -U datautil`;
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
# nohup python manage.py runserver $localIP:$cloudstat_port
$exit = `/bin/ps -elf|grep manage.py |grep -v grep`;
if (($? >> 8) == 1 ) {
  system("python ./CLOUDSTAT/manage.py runserver $localIP:$cloudstat_port &");
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
$exit = `curl -s http://$localIP:$cloudstat_port/app/startThread/1/`;
if (($exit =~ /Thread is already running/) || ($exit =~ /Thread started/))
 {
         print "\n  fetcher thread started successfully\n";
 }
else {
        print "\n Problem starting fetcher thread\n";
        print "\n exit: $exit\n";
        exit;
 }

while (1) {
   open (SNIFFER, "curl -s http://$localIP:$cloudstat_port/app/startCapturing/|json_pp |")|| die print "failed to get data: $!\n";
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
    $value11 = $stats[1] if $stats[0] =~ /INFLIGHT/;
    $value12 = $stats[1] if $stats[0] =~ /RTO/;

    #if ($key2 !~ /127.0.0/ ){  # don't worry about loopback addresses
    $key2=~s/^\s+//; # Remove space in the begining
    $key2=~s/\./_/g; # change . into _ because of graphite
    $keyjoined = join "-", $key1,$key2;
   #} 

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
    push @data, "$server.$host.system.tcp.traffic.INFLIGHT.$keyjoined $value11 $now\n"; 
    push @data, "$server.$host.system.tcp.traffic.RTO.$keyjoined $value12 $now\n"; 
  }

 close(SNIFFER);

  #print @data; 			# For Testing only 
  #print "\n------\n"; 			# For Testing only
  print GRAPHITE  @data;  		# Ship metrics to carbon server
  @data=();     			# Initialize for next set of metrics

  sleep $interval;
}

