#! /usr/bin/perl 

#use warnings;
#use strict;

use Scalar::Util qw(looks_like_number);
use Fcntl qw/:flock/;

open SELF, "< $0" or die ;
flock SELF, LOCK_EX | LOCK_NB  or die "Another instance of the same program is already running: $!";

require "../../../env.pl";                            # Sets up environment varilables for all agents

#setpriority(0,$$,19);                          # Uncomment if running script at a lower priority

# ------ End of Config options ---

#$SIG{INT} = \&signal_handler;
#$SIG{TERM} = \&signal_handler;

my @data = ();                                  # array to store metrics
my $now = `date +%s`;                           # metrics are sent with date stamp to graphite server

open(GRAPHITE, "| ../../../common/nc -w 25 $carbon_server $carbon_port") || die "failed to send: $!\n";

# ------------------------------agent specific sub routines-------------------

my @stats;
my @percentile;

# Start capturing
#while ($iterations-- > 0 ) {
while (1) {
$now = `date +%s`;
# graphite metrics are sent with date stamp 
 open (INTERFACE, "sudo ping -A -w 5 $peer |")|| die print "failed to get data: $!\n";
  while (<INTERFACE>) {
  next if (/^$/ || /^PING/ || /packets/ || /^rtt/ || /^---/) ;
  s/=/ /g;
  @stats= split;
  #print "$stats[9] is", looks_like_number($stats[10]) ? '' : ' not ', "a number\n";
  #print "$stats[10] is", looks_like_number($stats[10]) ? '' : ' not ', "a number\n";
  if(looks_like_number($stats[9])){
   push (@percentile, $stats[9]);
  }
  else {
   push (@percentile, $stats[10]);
  }
 }
 close(INTERFACE);

@percentile = sort {$a <=> $b} @percentile; 

push @data, "$server-netbench.$host.benchmark.pingtest.min $percentile[0] $now \n";
push @data, "$server-netbench.$host.benchmark.pingtest.max $percentile[-1] $now \n";
my $tmp = $percentile[sprintf("%.0f",(0.95*($#percentile)))];
 push @data, "$server-netbench.$host.benchmark.pingtest.95th $tmp $now \n";
my $tmp = $percentile[sprintf("%.0f",(0.99*($#percentile)))];
 push @data, "$server-netbench.$host.benchmark.pingtest.99th $tmp $now \n";

# Ship Metrics to carbon server --- 
  #print @data; 		# For Testing only 
  #print "\n------\n"; 		# For Testing only
  print GRAPHITE  @data;  	# Ship metrics to carbon server
  @data=();     		# Initialize for next set of metrics
  @percentile=();

  sleep 1;
} # while

