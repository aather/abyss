#! /usr/bin/perl 

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
my $iterations = 500;				# Test iterations
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
if ($num_args != 3) {
   print "\nUsage: netBW.pl hostname port. it should be a port number of netserver running on peer host"; 
   exit;
}
my @stats;
my @percentile;
my $peer = $ARGV[0];
my $port = $ARGV[1];
my $cport = $port + 1;

# Start Capturing
while ($iterations-- > 0 ) {
$now = `date +%s`;
open (INTERFACE, "netperf -H $peer -j -v 2 -l 10 -D 1 -p $port -- -P $cport |")|| die print "failed to get data: $!\n";

  while (<INTERFACE>) {
  next if (/^$/ );
  next if !(/^Interim/);
  s/:/ /g;
  @stats= split;
  push (@percentile, $stats[2]);
 }
 close(INTERFACE);

@percentile = sort {$a <=> $b} @percentile; 

push @data, "$server.$host.benchmark.BW.min $percentile[0] $now \n";
push @data, "$server.$host.benchmark.BW.max $percentile[-1] $now \n";
my $tmp = $percentile[sprintf("%.0f",(0.95*($#percentile)))];
 push @data, "$server.$host.benchmark.BW.95th $tmp $now \n";
my $tmp = $percentile[sprintf("%.0f",(0.99*($#percentile)))];
 push @data, "$server.$host.benchmark.BW.99th $tmp $now \n";

# Ship Metrics to carbon server --- 
  #print @data; 			# For Testing only 
  #print "\n------\n"; 			# For Testing only
  print GRAPHITE  @data;  		# Ship metrics to carbon server
  @data=();     			# Initialize for next set of metrics
  @percentile=();

  sleep $interval;
} # while
