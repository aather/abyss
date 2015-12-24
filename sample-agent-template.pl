#! /usr/bin/perl 

#use warnings;
#use strict;
use Fcntl qw/:flock/;

# Make sure to run only instance of the agent.
open SELF, "< $0" or die ;
flock SELF, LOCK_EX | LOCK_NB  or die "Another instance of the same program is already running: $!";

require "../../env.pl";           # Sets up environment varilables for all agents

#setpriority(0,$$,19);            # Uncomment if running script at a lower priority

$SIG{INT} = \&signal_handler;     # signal handler
$SIG{TERM} = \&signal_handler;

my @data = ();                    # array to store metrics
my $now = `date +%s`;             # metrics are sent with date stamp to graphite server

# open connection to graphite server
open(GRAPHITE, "| ../../common/ncat -i 100000ms $carbon_server $carbon_port") || die "failed to send: $!\n";

# ------------------------------agent specific sub routines-------------------

# Call your routines, collect_MyStats that stores metrics in @data and for shippment to graphite server

while (1) {

 $now = `date +%s`;     	# date stamp is required with every metrics
 collect_MyStats;

 #print @data; 			# For Testing only. 
 #print "\n------\n"; 		# For Testing only

 print GRAPHITE  @data;  	# Ship metrics to carbon server

 @data=();  			# Initialize for next set of metrics
 sleep $interval ;		# default interval is 5 seconds. Set it env.pl
}

# ----------------------- All subroutines -----------------

sub collect_MyStats {
 # Your Code here
 # push $mystats @data;   # store metrics in @data array for delivery to graphite server
}

sub signal_handler {
  die "Caught a signal $!";
  exit;
}
