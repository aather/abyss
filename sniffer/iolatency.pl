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
my $interval = 5;                               # Sets metrics collection granularity
#setpriority(0,$$,19);                          # Uncomment if running script at a lower priority

# ------ End of Config options ---

$SIG{INT} = \&signal_handler;
$SIG{TERM} = \&signal_handler;

my @data = ();                                  # array to store metrics
my $now = `date +%s`;                           # metrics are sent with date stamp to graphite server

# carbon server hostname: example: abyss.us-east-1.test.netflix.net
open(GRAPHITE, "| nc -w 25 $carbon_server.$region.$env.$domain $carbon_port") || die "failed to send: $!\n";

# ------------------------------agent specific sub routines-------------------

my @stats;
my @rpercentile;
my @wpercentile;

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


  #print @data; 			# For Testing only 
  #print "\n------\n"; 			# For Testing only
  print GRAPHITE  @data;  		# Ship metrics to carbon server
  @data=();     			# Initialize for next set of metrics
  @rpercentile=();
  @wpercentile=();

  sleep $interval;
}
