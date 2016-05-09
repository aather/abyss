#! /usr/bin/perl 

#use warnings;
#use strict;
use Fcntl qw/:flock/;

open SELF, "< $0" or die ;
flock SELF, LOCK_EX | LOCK_NB  or die "Another instance of the same program is already running: $!";

require "../../../../env.pl";                            # Sets up environment varilables for all agents

#setpriority(0,$$,19);                          # Uncomment if running script at a lower priority


#$SIG{INT} = \&signal_handler;
#$SIG{TERM} = \&signal_handler;

my @data = ();                                  # array to store metrics
my ($now, $connections) = @ARGV;

open(GRAPHITE, "| ../../../../common/nc -w 25 $carbon_server $carbon_port") || die "failed to send: $!\n";

# ------------------------------agent specific sub routines-------------------

my @stats;
my @percentile;

# Start Capturing
#while ($iterations-- > 0 ) {
while (1) {
open (INTERFACE, "netperf -H $peer -t TCP_RR -j -v 2 -l 10 -D 1 -p $net_dport -- -P $net_rport |")|| die print "failed to get data: $!\n";
  while (<INTERFACE>) {
  next if (/^$/ );
  next if !(/^Interim/);
  s/:/ /g;
  @stats= split;
  push (@percentile, $stats[2]);
 }
 close(INTERFACE);

@percentile = sort {$a <=> $b} @percentile; 

push @data, "$server-netbench.$host.benchmark.webserver.$connections.TPS.min $percentile[0] $now \n";
push @data, "$server-netbench.$host.benchmark.webserver.$connections.TPS.max $percentile[-1] $now \n";
my $tmp = $percentile[sprintf("%.0f",(0.95*($#percentile)))];
 push @data, "$server-netbench.$host.benchmark.webserver.$connections.TPS.95th $tmp $now \n";
my $tmp = $percentile[sprintf("%.0f",(0.99*($#percentile)))];
 push @data, "$server-netbench.$host.benchmark.webserver.$connections.TPS.99th $tmp $now \n";

# Ship Metrics to carbon server --- 
  #print @data; 		# For Testing only 
  #print "\n------\n"; 		# For Testing only
  print GRAPHITE  @data;  	# Ship metrics to carbon server
  @data=();     		# Initialize next set of metrics
  @percentile=();
  $now = $now + 5;
} # while

