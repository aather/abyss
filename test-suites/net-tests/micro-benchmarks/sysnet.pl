#! /usr/bin/perl 

#use warnings;
#use strict;
use Fcntl qw/:flock/;

open SELF, "< $0" or die ;
flock SELF, LOCK_EX | LOCK_NB  or die "Another instance of the same program is already running: $!";

require "../../../env.pl";				# Sets up environment varilables for all agents

#$SIG{INT} = \&signal_handler; 
#$SIG{TERM} = \&signal_handler; 

my @data = ();					# array to store metrics
my ($now) = @ARGV;
#my $now = `date +%s`;				# metrics are sent with date stamp to graphite server
# carbon server hostname: example: abyss.us-east-1.test.netflix.net
open(GRAPHITE, "| ../../../common/nc -w 25 $carbon_server $carbon_port") || die "failed to send: $!\n";
#open(GRAPHITE, "| ../../../common/ncat -i 100000ms $carbon_server $carbon_port ") || die "failed to send: $!\n";
 
# ------------------------------agent specific sub routines-------------------
sub build_HashArray;
sub collect_NetStats;
sub collect_TCPRetrans;
sub collect_TCPInfo;
sub collect_TCPSegs;
sub collect_IOStats;
sub collect_VMStats;
sub collect_CPUStats;
sub collect_NFSiostats;

while (1) {

$now = `date +%s`;				# metrics are sent with date stamp to graphite server
# Comment out stats that you are not interested in collecting 

 collect_NetStats;
 collect_TCPRetrans;
 collect_TCPInfo;
 collect_TCPSegs;
 collect_CPUStats;			# cpu stats
 collect_VMStats;			# vm stats

# print @data; 				# Testing only 
# print "\n------\n"; 			# Testing only
 print GRAPHITE @data;			# Ship metrics to graphite server
 @data=();  	

 sleep $interval ;  
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
  push @data, "$server-netbench.$host.benchmark.system.interface.$stats[0].rxbytes $stats[1] $now\n";
  push @data, "$server-netbench.$host.benchmark.system.interface.$stats[0].rxpackets $stats[2] $now\n";
  push @data, "$server-netbench.$host.benchmark.system.interface.$stats[0].txbytes $stats[9] $now\n";
  push @data, "$server-netbench.$host.benchmark.system.interface.$stats[0].txpackets $stats[10] $now\n";
 }
 close(INTERFACE);
}

sub collect_TCPRetrans {
  my @stats;
  open (TCP, "cat /proc/net/netstat |")|| die print "failed to get data: $!\n";
  while (<TCP>) {
  next if ( /SyncookiesSent/ || /Ip/);
  @stats = split;
  push @data, "$server-netbench.$host.benchmark.system.tcp.ListenDrops $stats[21] $now\n";
  push @data, "$server-netbench.$host.benchmark.system.tcp.TCPFastRetrans $stats[45] $now\n";
  push @data, "$server-netbench.$host.benchmark.system.tcp.TCPSlowStartRetrans $stats[47] $now\n";
  push @data, "$server-netbench.$host.benchmark.system.tcp.TCPTimeOuts $stats[48] $now\n";
  push @data, "$server-netbench.$host.benchmark.system.tcp.TCPBacklogDrop $stats[76] $now\n";
 }
close(TCP);
}

sub collect_TCPInfo {
#Netid  State      Recv-Q Send-Q Local Address:Port                 Peer Address:Port
#tcp    ESTAB      0      9369024 100.66.47.109:7421                 100.66.2.184:7421
# cubic wscale:9,9 rto:204 rtt:0.593/0.029 mss:1344 cwnd:401 ssthresh:267 bytes_acked:165908342209 segs_out:123447072 segs_in:9298694 send 7270.7Mbps 
# lastrcv:282920 pacing_rate 8721.2Mbps unacked:251 retrans:0/3112 rcv_space:2688

my @stats;
open (TCP, "ss -i '( dport = :7421 )' |")|| die print "failed to get data: $!\n";
while (<TCP>) {
  next if (/Netid/);
  @stats = split;
   if ( /^tcp/ ) {
    push @data, "$server.$host.system.tcp.tcpinfo.Recv-Q $stats[2] $now\n";
    push @data, "$server.$host.system.tcp.tcpinfo.Send-Q $stats[3] $now\n";
   }
  else {
        @rto = split /:/, $stats[2];
        push @data, "$server-netbench.$host.system.tcp.tcpinfo.$stats[0].$rto[0] $rto[1] $now\n";

        @rtt = split /:/, $stats[3];
        @rttext = split /\//, $rtt[1];
        push @data, "$server-netbench.$host.system.tcp.tcpinfo.$stats[0].$rtt[0].RTT $rttext[0] $now\n";
        push @data, "$server-netbench.$host.system.tcp.tcpinfo.$stats[0].$rtt[0].RTTVAR $rttext[1] $now\n";

        @mss = split /:/, $stats[4];
        push @data, "$server-netbench.$host.system.tcp.tcpinfo.$stats[0].$mss[0] $mss[1] $now\n";

        @cwnd = split /:/, $stats[5];
        push @data, "$server-netbench.$host.system.tcp.tcpinfo.$stats[0].$cwnd[0] $cwnd[1] $now\n";

        @ssth = split /:/, $stats[6];
        push @data, "$server-netbench.$host.system.tcp.tcpinfo.$stats[0].$ssth[0] $ssth[1] $now\n";
        $stats[11] =~ s/Mbps//;
        push @data, "$server-netbench.$host.system.tcp.tcpinfo.$stats[0].$stats[10] $stats[11] $now\n";

        # FOR BBR
        #$stats[10] =~ s/Mbps//;
        #push @data, "$server-netbench.$host.system.tcp.tcpinfo.$stats[0].$stats[9] $stats[10] $now\n";

        #@retrans = split /:/, $stats[15];
        #@retransext = split /\//, $retrans[1];
        #push @data, "$server-netbench.$host.system.tcp.tcpinfo.$stats[0].$retrans[0].RETRANS $retransext[0] $now\n";
        #push @data, "$server-netbench.$host.system.tcp.tcpinfo.$stats[0].$retrans[0].RETRANSDIVIDER $retransext[1] $now\n";

        @rcv = split /:/, $stats[16];
        push @data, "$server-netbench.$host.system.tcp.tcpinfo.$stats[0].$rcv[0] $rcv[1] $now\n";
      }
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
   push @data, "$server-netbench.$host.benchmark.system.tcp.ActiveOpens $stats[5] $now\n";
   push @data, "$server-netbench.$host.benchmark.system.tcp.PassiveOpens $stats[6] $now\n";
   push @data, "$server-netbench.$host.benchmark.system.tcp.EstabRsts $stats[8] $now\n"; 
   push @data, "$server-netbench.$host.benchmark.system.tcp.InSegs $stats[10] $now\n";
   push @data, "$server-netbench.$host.benchmark.system.tcp.OutSegs $stats[11] $now\n";
   push @data, "$server-netbench.$host.benchmark.system.tcp.RetransSegs $stats[12] $now\n";
   push @data, "$server-netbench.$host.benchmark.system.tcp.OutRst $stats[14] $now\n";  
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

 push @data, "$server-netbench.$host.benchmark.system.mem.free_cached $free_cached $now\n";
 push @data, "$server-netbench.$host.benchmark.system.mem.free_unused $free_unused $now\n";
 push @data, "$server-netbench.$host.benchmark.system.mem.used $used $now\n";
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
  push @data, "$server-netbench.$host.benchmark.system.CPU.$stats[0] $stats[1] $now\n";
 } 
 }
close(MPSTAT);
 foreach $key (keys %cpuhash){
  $user = $cpuhash{$key}[0] + $cpuhash{$key}[1];
  $sys = $cpuhash{$key}[2];
  $idle = $cpuhash{$key}[3] + $cpuhash{$key}[4];
  $intr = $cpuhash{$key}[5];
  $softirq = $cpuhash{$key}[6];

  push @data, "$server-netbench.$host.benchmark.system.CPU.$key.user $user $now\n";
  push @data, "$server-netbench.$host.benchmark.system.CPU.$key.sys $sys $now\n";
  push @data, "$server-netbench.$host.benchmark.system.CPU.$key.idle $idle $now\n";
  push @data, "$server-netbench.$host.benchmark.system.CPU.$key.intr $intr $now\n";
  push @data, "$server-netbench.$host.benchmark.system.CPU.$key.softirq $softirq $now\n";
 }
}
