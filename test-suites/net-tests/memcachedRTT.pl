#! /usr/bin/perl 
use Data::Dumper qw(Dumper);

#use warnings;
use strict;

# ---- Start of Config options -----

my $region = $ENV{'EC2_REGION'};                # Sets Amazon Region: us-east-1, us-west-1..
my $host = $ENV{'EC2_INSTANCE_ID'};             # Sets Amazon cloud instance id: i-c3a4e33d
my $server = "cluster.$ENV{'NETFLIX_APP'}";     # Sets Server name or Application cluster name
my $env = $ENV{'NETFLIX_ENVIRONMENT'};          # Sets deployment environment: test or prod
my $domain = "netflix.net";                     # Sets domain: netflix.net, cloudperf.net
my $carbon_server = "abyss";                    # Sets hostname of graphite carbon server for storing metrics
my $carbon_port = "7001";                       # Port where graphite carbon server is listening
my $interval = 1;                               # Sets metrics collection granularity
my $iterations = 500;                           # Test iterations
my $RPS = 70000;                        	# Testing for RPS rates
#setpriority(0,$$,19);                          # Uncomment if running script at a lower priority

# ------ End of Config options ---

$SIG{INT} = \&signal_handler;
$SIG{TERM} = \&signal_handler;

my @data = ();                                  # array to store metrics
my $now = `date +%s`;                           # metrics are sent with date stamp to graphite server

# carbon server hostname: example: abyss.us-east-1.test.netflix.net
open(GRAPHITE, "| nc -w 25 $carbon_server.$region.$env.$domain $carbon_port") || die "failed to send: $!\n";

# ------------------------------agent specific sub routines-------------------

my $num_args = $#ARGV + 2;
if ($num_args != 2) {
   print "\nUsage: memcachedRTT.pl hostname port. it should be a port number of memcached running on peer host";
   exit;
}

my @stats;
my @percentile;
my %hash;
my $total;
my $i=0;
my $peer = $ARGV[0];
my $port = $ARGV[1];
my $exit;

# Warm up the memcache with 2 million entries of size 100 bytes before starting RPS test

$exit = `./mcblaster -p $port -t 8 -z 100 -k 2000000  -d 30 -w 20000 -c 10 -r 1 $peer 2>&1`;
 if ($exit =~ /Hostname lookup failed/) {
   print "\nHostname lookup failed: $!\n";
   printf "command exited with value %d\n", $? >> 8;
   exit;
 }

# Capture metrics every 5 seconds until interrupted.
while ($iterations-- > 0 ) {
$now = `date +%s`;
open (INTERFACE, " ./mcblaster -p $port -z 100 -d 10 -r $RPS -c 20 $peer |")|| die print "failed to get data: $!\n";
  while (<INTERFACE>) {
  next if (/^$/);
  last if (/RTT distribution for 'set' requests:/);
  if (/^\[/  || /^Over/){
    s/\[/ /g;
    s/\]/ /g;
    s/:/ /g;
    if (/^Over/){
    @stats = split;
    $hash{$stats[0]} = $stats[3]; 
    }
    else {
    @stats = split;
    $hash{$stats[0]} = $stats[1]; 
   }
  }
 }
 close(INTERFACE);

 foreach my $key (keys %hash) {
	$total = $total + $hash{$key};
	push @data, "$server.$host.benchmark.memcached.$key $hash{$key} $now \n";

     }
push @data, "$server.$host.benchmark.memcached.total $total $now \n";

  #print Dumper \%hash ;		# For Testing only
  #print @data; 			# For Testing only 
  #print "\n------\n"; 			# For Testing only
  print GRAPHITE  @data;  		# Ship metrics to graphite carbon server
  @data=();     			# Initialize for next set of metrics
  $total=0;  				# initialize total count

#initialize the hash for next set of metrics

  foreach my $key (keys %hash){
        delete $hash{$_};
    }

  sleep $interval;

}
