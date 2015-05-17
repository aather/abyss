#! /usr/bin/perl 

#use warnings;
use strict;

my $num_args = $#ARGV + 2;
if ($num_args != 2) {
   print "\nUsage: netBW.pl hostname port. it should be a port number of netserver running on peer host"; 
   exit;
}
my @data = ();
my $now = `date +%s`;
my $region = $ENV{'EC2_REGION'};
my $env = $ENV{'NETFLIX_ENVIRONMENT'}; # test or prod
my $host = "$ENV{'EC2_INSTANCE_ID'}";  # ex: i-c3a4e33d 
my $server = "cluster.$ENV{'NETFLIX_APP'}";   # ex:  abcassandra_2
my $carbon_server;
my @stats;
my @percentile;
my $iterations = 500;
my $interval = 1;
my $peer = $ARGV[0];
my $port = $ARGV[1];

if ( $env =~ /prod/) {
 $carbon_server = "abyss.$region.prod.netflix.net";
 }
else {
 $carbon_server = "abyss.$region.test.netflix.net";
 }

# Run at lowest priority possible to avoid competing for cpu cycles with the workload
#setpriority(0,$$,19);

# Open a connection to the carbon server where we will be pushing the metrics
open(GRAPHITE, "| nc -w 15 $carbon_server 7001") || die print "failed to send data: $!\n";

# Capture metrics every 5 seconds until interrupted.
while ($iterations-- > 0 ) {
$now = `date +%s`;
# graphite metrics are sent with date stamp 
 open (INTERFACE, "netperf -H $peer -j -v 2 -l 10 -D 1 -p $port -- -P 7102 |")|| die print "failed to get data: $!\n";
  while (<INTERFACE>) {
  next if (/^$/ );
  next if !(/^Interim/);
  s/:/ /g;
  @stats= split;
  push (@percentile, $stats[2]);
 }
 close(INTERFACE);

# Sort
@percentile = sort {$a <=> $b} @percentile; 

# Print min and max
push @data, "$server.$host.benchmark.BW.min $percentile[0] $now \n";
push @data, "$server.$host.benchmark.BW.max $percentile[-1] $now \n";

# Print 95% percentile
my $tmp = $percentile[sprintf("%.0f",(0.95*($#percentile)))];
 push @data, "$server.$host.benchmark.BW.95th $tmp $now \n";
# Print 99% percentile
my $tmp = $percentile[sprintf("%.0f",(0.99*($#percentile)))];
 push @data, "$server.$host.benchmark.BW.99th $tmp $now \n";
#
# Ship Metrics to carbon server --- 
  #print @data; # For Testing only 
  #print "\n------\n"; # for Testing only
  print GRAPHITE  @data;  # Shipping metrics to carbon server
  @data=();     # Initialize the array for next set of metrics
  @percentile=();

  sleep $interval;
} # while
