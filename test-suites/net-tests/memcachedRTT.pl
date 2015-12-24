#! /usr/bin/perl 
use Data::Dumper qw(Dumper);

#use warnings;
#use strict;
use Fcntl qw/:flock/;

open SELF, "< $0" or die ;
flock SELF, LOCK_EX | LOCK_NB  or die "Another instance of the same program is already running: $!";

require "../../env.pl";                            # Sets up environment varilables for all agents

#setpriority(0,$$,19);                          # Uncomment if running script at a lower priority

#$SIG{INT} = \&signal_handler;
#$SIG{TERM} = \&signal_handler;

my @data = ();                                  # array to store metrics
# ------------------------------agent specific -------------------

my @stats;
my @percentile;
my %hash;
my $total;
my $i=0;
my $exit;

# Warm up the memcache with 2 million entries of size 100 bytes before starting RPS test

$exit = `../../common/mcblaster -p $mem_port -z 100 -k 2000000  -d 30 -w 10000 -c 10 -r 1 $peer 2>&1`;
if ($exit =~ /Hostname lookup failed/) {
  print "\nHostname lookup failed: $!\n";
  printf "command exited with value %d\n", $? >> 8;
  exit;
}

# open a connection to graphite server
open(GRAPHITE, "| ../../common/nc -w 25 $carbon_server $carbon_port") || die "failed to send: $!\n";

# Plan is to keep all RPS rates within the same time frame
my $time = `date +%s`;
my $now = $time;
my $loops = $iterations;

foreach my $RPS (@RPS){
  my @args = ("./sysmemRTT.pl", "$now", "$RPS");
  if (my $pid = fork) {
     # No waiting for child 
     #  waitpid($pid);  
  }
  else {
     # I am child, now execute external command in context of new process.
     exec(@args);
  }
  while ($loops-- > 0 ) {
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
  # ship it
  foreach my $key (keys %hash) {
    $total = $total + $hash{$key};
    if ($key =~ /Over/){
      push @data, "$server-netbench.$host.benchmark.memcached.$RPS.$key-10ms $hash{$key} $now \n";
    }
    else{
      push @data, "$server-netbench.$host.benchmark.memcached.$RPS.$key-us $hash{$key} $now \n";
    }
  }
  push @data, "$server-netbench.$host.benchmark.memcached.$RPS.total-Packets $total $now \n";

  #print Dumper \%hash ;		# For Testing only
  print @data; 			# For Testing only 
  print "\n------\n"; 			# For Testing only
  print GRAPHITE  @data;  		# Ship metrics to graphite carbon server

  @data=();     			# Initialize for next set of metrics
  $total=0;  				# initialize total count
  $now = $now + 5;  # Make it look like sample is shipped every 5 seconds

  foreach my $key (keys %hash){
    delete $hash{$_};
   }
  }
  `pkill sysmemRTT.pl`;
  $loops=$iterations;
  $now = $time;  # Reset $now for new RPS rate
}

