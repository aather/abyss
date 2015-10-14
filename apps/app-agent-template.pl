#! /usr/bin/perl 

use Fcntl qw/:flock/;

# Make sure to run only instance of the agent.
open SELF, "< $0" or die ;
flock SELF, LOCK_EX | LOCK_NB  or die "Another instance of the same program is already running: $!";

require "../../env.pl";           # Sets up environment varilables for all agents
#setpriority(0,$$,19);            # Uncomment if running script at a lower priority

$SIG{INT} = \&signal_handler;     # signal handler for java agent to detach 
$SIG{TERM} = \&signal_handler;

my @data = ();                    # array to store metrics
my $now = `date +%s`;             # metrics are sent with date stamp to graphite server

# open connection to graphite server
open(GRAPHITE, "| nc -w 50 $carbon_server $carbon_port") || die "failed to send: $!\n";

# ------------------------------agent specific sub routines-------------------
sub build_HashArray;
sub collect_MyStats;

my $token = `jps|grep MYPROCESS`;    # search for java process to attach
my @pid = split / /, $token;
my $exit = `java -jar ../jolokia-jvm-1.2.2-agent.jar start $pid[0] 2>&1`;  # Attaching to JMX port
 if ($exit =~ /Cannot attach/) {
   print "\nfailed to connect to JMX port: $!\n";
   printf "command exited with value %d\n", $? >> 8;
   exit;
 }

# Call routines and store metrics in array @data and then ship 
# to graphite server
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

sub signal_handler {
 `java -jar ../jolokia-jvm-1.2.2-agent.jar --quiet stop $pid[0]`;
  die "Caught a signal $!";
}

sub build_HashArray {
  my ($keys, $values) = @_;
  my %sub_hash;
  foreach my $key (@$keys){
   foreach my $value (@$values){
    push (@{$sub_hash{$key}}, $value);
   }
  }
  return %sub_hash;
 }

sub collect_MyStats {
 # Your Code here
 # push $mystats @data;   # store it in @data for delivery to graphite server
}
