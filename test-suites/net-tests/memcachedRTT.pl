#! /usr/bin/perl 
use Data::Dumper qw(Dumper);

#use warnings;
#use strict;

require "../env.pl";                            # Sets up environment varilables for all agents

#setpriority(0,$$,19);                          # Uncomment if running script at a lower priority

$SIG{INT} = \&signal_handler;
$SIG{TERM} = \&signal_handler;

my @data = ();                                  # array to store metrics
my $now = `date +%s`;                           # metrics are sent with date stamp to graphite server

open(GRAPHITE, "| nc -w 25 $carbon_server $carbon_port") || die "failed to send: $!\n";

# ------------------------------agent specific -------------------

my @stats;
my @percentile;
my %hash;
my $total;
my $i=0;
my $exit;

# Warm up the memcache with 2 million entries of size 100 bytes before starting RPS test

$exit = `./mcblaster -p $mem_port -t 8 -z 100 -k 2000000  -d 30 -w $RPS -c 10 -r 1 $peer 2>&1`;
 if ($exit =~ /Hostname lookup failed/) {
   print "\nHostname lookup failed: $!\n";
   printf "command exited with value %d\n", $? >> 8;
   exit;
 }

# Capture metrics every 5 seconds until interrupted.
while ($iterations-- > 0 ) {
$now = `date +%s`;
open (INTERFACE, " ./mcblaster -p $mem_port -z 100 -d 10 -r $RPS -c 20 $peer |")|| die print "failed to get data: $!\n";
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
