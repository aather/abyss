#! /usr/bin/perl 

#use warnings;
#use strict;

require "../../env.pl";                            # Sets up environment varilables for all agents

#setpriority(0,$$,19);                          # Uncomment if running script at a lower priority

# ------ End of Config options ---

$SIG{INT} = \&signal_handler;
$SIG{TERM} = \&signal_handler;

my @data = ();                                  # array to store metrics
my $now = `date +%s`;                           # metrics are sent with date stamp to graphite server
my $iterations = 500;                           # Test iterations

open(GRAPHITE, "| nc -w 25 $carbon_server $carbon_port") || die "failed to send: $!\n";

# ------------------------------agent specific sub routines-------------------

my @stats;
my @percentile;

# Start capturing
while ($iterations-- > 0 ) {
$now = `date +%s`;
# graphite metrics are sent with date stamp 
 open (INTERFACE, "ping -A -w 10 $peer |")|| die print "failed to get data: $!\n";
  while (<INTERFACE>) {
  next if (/^$/ || /^PING/ || /packets/ || /^rtt/ || /^---/) ;
  s/=/ /g;
  @stats= split;
  push (@percentile, $stats[10]);
 }
 close(INTERFACE);

@percentile = sort {$a <=> $b} @percentile; 

push @data, "$server.$host.benchmark.pingtest.min $percentile[0] $now \n";
push @data, "$server.$host.benchmark.pingtest.max $percentile[-1] $now \n";
my $tmp = $percentile[sprintf("%.0f",(0.95*($#percentile)))];
 push @data, "$server.$host.benchmark.pingtest.95th $tmp $now \n";
my $tmp = $percentile[sprintf("%.0f",(0.99*($#percentile)))];
 push @data, "$server.$host.benchmark.pingtest.99th $tmp $now \n";

# Ship Metrics to carbon server --- 
  #print @data; 		# For Testing only 
  #print "\n------\n"; 		# For Testing only
  print GRAPHITE  @data;  	# Ship metrics to carbon server
  @data=();     		# Initialize for next set of metrics
  @percentile=();

  sleep 1;
} # while
