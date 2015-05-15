#! /usr/bin/perl 

#use warnings;
use strict;

my @data = ();
my $now = `date +%s`;
my $env = $ENV{'NETFLIX_ENVIRONMENT'}; # test or prod
my $host = "$ENV{'EC2_INSTANCE_ID'}";  # ex: i-c3a4e33d 
my $region = $ENV{'EC2_REGION'};
my $server = "cluster.$ENV{'NETFLIX_APP'}";   # ex:  abcassandra_2
my $localIP = $ENV{'EC2_LOCAL_IPV4'};
my $publicIP =  $ENV{'EC2_PUBLIC_IPV4'};
my $carbon_server;
my @stats;
my @rpercentile;
my @wpercentile;
my $interval = 5;

# I have setup two servers to store metrics. One is in production and other is in test
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

# Run at lowest priority possible to avoid competing for cpu cycles with the workload
#setpriority(0,$$,19);

while (1) {
   open (PERF, " ./diskstats|")|| die print "failed to get data: $!\n";
   $now = `date +%s`;
   while (<PERF>) {
   #print;
  @stats= split;
  #print "stats:$stats[0]\n";
  push (@rpercentile, $stats[1]) if ($stats[0] =~ /R/);
  push (@wpercentile, $stats[1]) if ($stats[0] =~ /W/);
  }
 close(PERF);

# Sort
@rpercentile = sort {$a <=> $b} @rpercentile;
@wpercentile = sort {$a <=> $b} @wpercentile;

# print min and max
push @data, "$server.$host.system.io.Latency.Read.min $rpercentile[0] $now \n";
push @data, "$server.$host.system.io.Latency.Read.max $rpercentile[-1] $now \n";
push @data, "$server.$host.system.io.Latency.Write.min $wpercentile[0] $now \n";
push @data, "$server.$host.system.io.Latency.Write.max $wpercentile[-1] $now \n";
# Print 95% percentile
my $tmp = $rpercentile[sprintf("%.0f",(0.95*($#rpercentile)))];
 push @data, "$server.$host.system.io.Latency.Read.95th $tmp $now \n";
my $tmp = $wpercentile[sprintf("%.0f",(0.95*($#wpercentile)))];
 push @data, "$server.$host.system.io.Latency.Write.95th $tmp $now \n";
# Print 99% percentile
my $tmp = $rpercentile[sprintf("%.0f",(0.99*($#rpercentile)))];
 push @data, "$server.$host.system.io.Latency.Read.99th $tmp $now \n";
my $tmp = $wpercentile[sprintf("%.0f",(0.99*($#wpercentile)))];
 push @data, "$server.$host.system.io.Latency.Write.99th $tmp $now \n";


# Ship Metrics to carbon server --- 
  #print @data; # For Testing only 
  #print "\n------\n"; # for Testing only
  print GRAPHITE  @data;  # Shipping the metrics to carbon server
  @data=();     # Initialize the array for next set of metrics
  @rpercentile=();
  @wpercentile=();

  sleep $interval;
}
