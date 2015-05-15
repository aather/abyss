#! /usr/bin/perl 

#use warnings;
use strict;

my $num_args = $#ARGV + 1;
if ($num_args != 1) {
   print "\nUsage: pingRTT.pl EC2_PUBLIC_HOSTNAME or IP ADDRESS\n";
   exit;
}

my @data = ();
my $now = `date +%s`;
my $env = $ENV{'NETFLIX_ENVIRONMENT'}; # test or prod
my $region = $ENV{'EC2_REGION'};
my $host = "$ENV{'EC2_INSTANCE_ID'}";  # ex: i-c3a4e33d 
my $server = "cluster.$ENV{'NETFLIX_APP'}";   # ex:  abcassandra_2
my $carbon_server;
my @stats;
my @percentile;
my $iterations = 500;
my $interval = 1;
my $peer = $ARGV[0];

if ( $env =~ /prod/) {
 $carbon_server = "abyss.$region.prod.netflix.net";
 }
else {
 $carbon_server = "abyss.$region.test.netflix.net";
 }

# Run at lowest priority possible to avoid competing for cpu cycles with the workload
#setpriority(0,$$,19);

# Open a connection to the carbon server where we will be pushing the metrics
open(GRAPHITE, "| nc -w 25 $carbon_server 7001") || die print "failed to send data: $!\n";

# Capture metrics every 5 seconds until interrupted.
while ($iterations-- > 0 ) {
$now = `date +%s`;
# graphite metrics are sent with date stamp 
 open (INTERFACE, "ping -A -w 5 $peer |")|| die print "failed to get data: $!\n";
  while (<INTERFACE>) {
  next if (/^$/ || /^PING/ || /packets/ || /^rtt/ || /^---/) ;
  s/=/ /g;
  @stats= split;
  push (@percentile, $stats[10]);
 }
 close(INTERFACE);

# Sort
@percentile = sort {$a <=> $b} @percentile; 

# Print min and max
push @data, "$server.$host.benchmark.pingtest.min $percentile[0] $now \n";
push @data, "$server.$host.benchmark.pingtest.max $percentile[-1] $now \n";

# Print 95% percentile
my $tmp = $percentile[sprintf("%.0f",(0.95*($#percentile)))];
 push @data, "$server.$host.benchmark.pingtest.95th $tmp $now \n";
# Print 99% percentile
my $tmp = $percentile[sprintf("%.0f",(0.99*($#percentile)))];
 push @data, "$server.$host.benchmark.pingtest.99th $tmp $now \n";

# Ship Metrics to carbon server --- 
  #print @data; # For Testing only 
  #print "\n------\n"; # for Testing only
  print GRAPHITE  @data;  # Shipping the metrics to carbon server
  @data=();     # Initialize the array for next set of metrics
  @percentile=();

  sleep $interval;
} # while
