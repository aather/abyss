#! /usr/bin/perl 

#use warnings;
#use strict;
use Fcntl qw/:flock/;

#open SELF, "< $0" or die ;
#flock SELF, LOCK_EX | LOCK_NB  or die "Another instance of the same program is already running: $!";

require "../../env.pl";				# Sets up environment varilables for all agents

#$SIG{INT} = \&signal_handler; 
#$SIG{TERM} = \&signal_handler; 

my @data = ();					# array to store metrics

# Takes start time, test name, test types, filesystem, block

my ($now, $RPS) = @ARGV;

# carbon server hostname: example: abyss.us-east-1.test.netflix.net
open(GRAPHITE, "| ../../common/nc -w 25 $carbon_server $carbon_port") || die "failed to send: $!\n";
 
# ------------------------------agent specific sub routines-------------------
sub build_HashArray;
sub collect_NetStats;
sub collect_TCPRetrans;
sub collect_TCPSegs;
sub collect_IOStats;
sub collect_VMStats;
sub collect_CPUStats;
sub collect_NFSiostats;

while (1) {

# Comment out stats that you are not interested in collecting 

 collect_NetStats;
 collect_TCPRetrans;
 collect_TCPSegs;
 collect_CPUStats;			# cpu stats
 collect_VMStats;			# vm stats

 #print @data; 				# Testing only 
 #print "\n------\n"; 			# Testing only
 print GRAPHITE @data;			# Ship metrics to graphite server
 @data=();  	

 sleep $interval ;  
 $now = $now + $interval;
}

# ----------------------- subroutines -----------------

sub signal_handler {
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

sub collect_NetStats {
 my @stats;
 open (INTERFACE, "cat /proc/net/dev |")|| die print "failed to get data: $!\n";
  while (<INTERFACE>) {
  next if (/^$/ || /^Inter/ || /face/) ;
  s/:/ /g;
  @stats = split;
  push @data, "$server-netbench.$host.benchmark.memcached.$RPS.system.interface.$stats[0].rxbytes $stats[1] $now\n";
  push @data, "$server-netbench.$host.benchmark.memcached.$RPS.system.interface.$stats[0].rxpackets $stats[2] $now\n";
  push @data, "$server-netbench.$host.benchmark.memcached.$RPS.system.interface.$stats[0].txbytes $stats[9] $now\n";
  push @data, "$server-netbench.$host.benchmark.memcached.$RPS.system.interface.$stats[0].txpackets $stats[10] $now\n";
 }
 close(INTERFACE);
}

sub collect_TCPRetrans {
  my @stats;
  open (TCP, "cat /proc/net/netstat |")|| die print "failed to get data: $!\n";
  while (<TCP>) {
  next if ( /SyncookiesSent/ || /Ip/);
  @stats = split;
  push @data, "$server-netbench.$host.benchmark.memcached.$RPS.system.tcp.ListenDrops $stats[21] $now\n";
  push @data, "$server-netbench.$host.benchmark.memcached.$RPS.system.tcp.TCPFastRetrans $stats[45] $now\n";
  push @data, "$server-netbench.$host.benchmark.memcached.$RPS.system.tcp.TCPSlowStartRetrans $stats[47] $now\n";
  push @data, "$server-netbench.$host.benchmark.memcached.$RPS.system.tcp.TCPTimeOuts $stats[48] $now\n";
  push @data, "$server-netbench.$host.benchmark.memcached.$RPS.system.tcp.TCPBacklogDrop $stats[75] $now\n";
 }
close(TCP);
}

sub collect_TCPSegs {
  my @stats;
 # Tcp: RtoAlgorithm RtoMin RtoMax MaxConn ActiveOpens PassiveOpens AttemptFails EstabResets CurrEstab InSegs OutSegs RetransSegs 
 # Tcp: 1 200 120000 -1 4828 4261 5 5 380 515264340 1324251168 2482 0 25 0
  open (TCP, "cat /proc/net/snmp |")|| die print "failed to get data: $!\n";
  while (<TCP>) {
   next if (!/Tcp/);
   next if (/RtoAlgo/);
   @stats = split; 
   push @data, "$server-netbench.$host.benchmark.memcached.$RPS.system.tcp.ActiveOpens $stats[5] $now\n";
   push @data, "$server-netbench.$host.benchmark.memcached.$RPS.system.tcp.PassiveOpens $stats[6] $now\n";
   push @data, "$server-netbench.$host.benchmark.memcached.$RPS.system.tcp.EstabRsts $stats[8] $now\n"; 
   push @data, "$server-netbench.$host.benchmark.memcached.$RPS.system.tcp.InSegs $stats[10] $now\n";
   push @data, "$server-netbench.$host.benchmark.memcached.$RPS.system.tcp.OutSegs $stats[11] $now\n";
   push @data, "$server-netbench.$host.benchmark.memcached.$RPS.system.tcp.RetransSegs $stats[12] $now\n";
   push @data, "$server-netbench.$host.benchmark.memcached.$RPS.system.tcp.OutRst $stats[14] $now\n";  
 }
close(TCP);
}
		
sub collect_VMStats {
 my @Array;
 my @stats;
 my $used;
 my $free_cached;
 my $free_unused;

 open(VMSTAT, "head -4 /proc/meminfo |")|| die print "failed to get data: $!\n";
 while (<VMSTAT>) {
 next if (/^$/);
 s/://g;   # trim ":"
 @stats = split;
 push @Array,$stats[1];
 }
close (VMSTAT);
 $free_cached = $Array[2] + $Array[3];
 $free_unused = $Array[1];
 $used = $Array[0] - $free_cached - $free_unused;

 push @data, "$server-netbench.$host.benchmark.memcached.$RPS.system.mem.free_cached $free_cached $now\n";
 push @data, "$server-netbench..$host.benchmark.memcached.$RPS.system.mem.free_unused $free_unused $now\n";
 push @data, "$server-netbench.$host.benchmark.memcached.$RPS.system.mem.used $used $now\n";
}

sub collect_CPUStats {
 my %cpuhash;
 my @stats;
 my $key;
 my $values;
 my $user;
 my $sys;
 my $idle;
 my $intr;

 open(MPSTAT, "cat /proc/stat |")|| die print "failed to get data: $!\n";
 while (<MPSTAT>) {
 next if (/^$/ || /^intr/ || /^btime/ || /^processes/ || /^softirq/) ;
 if ( /^cpu/ ) {
  ($key, $values) = split;
  @stats = split, $values;
  shift(@stats);
  $cpuhash{$key} = [ @stats ];
  }
 else {  # also needs to collect running and blocked processes
  @stats = split;
  push @data, "$server-netbench.$host.benchmark.memcached.$RPS.system.CPU.$stats[0] $stats[1] $now\n";
 } 
 }
close(MPSTAT);
 foreach $key (keys %cpuhash){
  $user = $cpuhash{$key}[0] + $cpuhash{$key}[1];
  $sys = $cpuhash{$key}[2];
  $idle = $cpuhash{$key}[3] + $cpuhash{$key}[4];
  $intr = $cpuhash{$key}[5] + $cpuhash{$key}[6];

# benchmark.memcached.30000  
  push @data, "$server-netbench.$host.benchmark.memcached.$RPS.system.CPU.$key.user $user $now\n";
  push @data, "$server-netbench.$host.benchmark.memcached.$RPS.system.CPU.$key.sys $sys $now\n";
  push @data, "$server-netbench.$host.benchmark.memcached.$RPS.system.CPU.$key.idle $idle $now\n";
  push @data, "$server-netbench.$host.benchmark.memcached.$RPS.system.CPU.$key.intr $intr $now\n";
 }
}

