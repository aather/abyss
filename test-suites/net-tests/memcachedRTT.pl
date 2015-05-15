#! /usr/bin/perl 
use Data::Dumper qw(Dumper);

#use warnings;
use strict;

my $num_args = $#ARGV + 1;
if ($num_args != 1) {
   print "\nUsage: memcachedRTT.pl EC2_PUBLIC_HOSTNAME or IP ADDRESS\n";
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
my $RPS = 70000;  # Testing for 70000 RPS instead of varying RPS 
# optional testing for various RPS. Starts with 10000 and ramp it up all the way to 100000
my @TPS = ("10000", "20000", "30000", "40000", "50000", "60000", "70000", "80000", "900000", "100000");
my %hash;
my $total;
my $i=0;
my $peer = $ARGV[0];
my $exit;

if ( $env =~ /prod/) {
 $carbon_server = "abyss.$region.prod.netflix.net";
 }
else {
 $carbon_server = "abyss.$region.test.netflix.net";
 }

# optional: Run at lowest priority possible to avoid competing for cpu cycles with the workload
#setpriority(0,$$,19);

# Warm up the memcache with 2 million entries of size 100 bytes
$exit = `./mcblaster -p 7002 -t 8 -z 100 -k 2000000  -d 30 -w 20000 -c 10 -r 1 $peer 2>&1`;
 if ($exit =~ /Hostname lookup failed/) {
   print "\nHostname lookup failed: $!\n";
   printf "command exited with value %d\n", $? >> 8;
   exit;
 }

# Open a connection to the carbon server where we will be pushing the metrics
open(GRAPHITE, "| nc -w 25 $carbon_server 7001") || die print "failed to send data: $!\n";

# Capture metrics every 5 seconds until interrupted.
while ($iterations-- > 0 ) {
$now = `date +%s`;
 #------------------
 # Uncomment it if interested in varying RPS rate instead of fixed 70000
 #open (INTERFACE, " ./mcblaster -p 7002 -z 100 -d 10 -r $TPS[$i] -c 20 $peer |")|| die print "failed to get data: $!\n";
 # ----------------
 open (INTERFACE, " ./mcblaster -p 7002 -z 100 -d 10 -r 50000 -c 20 $peer |")|| die print "failed to get data: $!\n";
  while (<INTERFACE>) {
  next if (/^$/);
  last if (/RTT distribution for 'set' requests:/);
  #next if !(/^\[/);
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

#print Dumper \%hash ;

# Ship Metrics to carbon server --- 
  #print @data; # For Testing only 
  #print "\n------\n"; # for Testing only
  print GRAPHITE  @data;  # Shipping the metrics to carbon server
  @data=();     # Initialize the array for next set of metrics
  $total=0;  # initialize total count
  #
  # ------
  # Uncomment it if interested in varying TPS rate instead of 70000 fixed rate
  #if ($i == $#TPS){ $i=0; }
  #else { $i=$i+1;}
  #----------

#initialize the hash
  foreach my $key (keys %hash){
        delete $hash{$_};
    }
  sleep $interval;

} # while
