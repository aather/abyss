#! /usr/bin/perl 

#use warnings;
#use strict;
use Fcntl qw/:flock/;

#open SELF, "< $0" or die ;
#flock SELF, LOCK_EX | LOCK_NB  or die "Another instance of the same program is already running: $!";

require "../env.pl";				# Sets up environment varilables for all agents

#$SIG{INT} = \&signal_handler; 
#$SIG{TERM} = \&signal_handler; 

my @data = ();					# array to store metrics
my $now = `date +%s`;				# metrics are sent with date stamp to graphite server

# carbon server hostname: example: abyss.us-east-1.test.netflix.net
open(GRAPHITE, "| ../common/nc -w 25 $carbon_server $carbon_port") || die "failed to send: $!\n";
 
# ------------------------------agent specific sub routines-------------------
sub build_HashArray;
sub collect_NetStats;
sub collect_TCPRetrans;
sub collect_TCPSegs;
sub collect_IOStats;
sub collect_VMStats;
sub collect_CPUStats;
sub collect_NFSiostats;
sub collect_ETHTool;

while (1) {

 $now = `date +%s`;

# Comment out stats that you are not interested in collecting 

 collect_NetStats;       		# Net stats 
 collect_TCPRetrans;     		# TCP stats 
 collect_TCPSegs;			# TCP segments
 collect_IOStats;			# io stats
 collect_CPUStats;			# cpu stats
 collect_VMStats;			# vm stats
 collect_NFSiostats;			# NFS stats
 collect_ETHTool;

 #print @data; 				# Testing only 
 #print "\n------\n"; 			# Testing only
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
  push @data, "$server.$host.system.interface.$stats[0].rxbytes $stats[1] $now\n";
  push @data, "$server.$host.system.interface.$stats[0].rxpackets $stats[2] $now\n";
  push @data, "$server.$host.system.interface.$stats[0].txbytes $stats[9] $now\n";
  push @data, "$server.$host.system.interface.$stats[0].txpackets $stats[10] $now\n";
 }
 close(INTERFACE);
}

sub collect_TCPRetrans {
  my @stats;
  open (TCP, "cat /proc/net/netstat |")|| die print "failed to get data: $!\n";
  while (<TCP>) {
  next if ( /SyncookiesSent/ || /Ip/);
  @stats = split;
  push @data, "$server.$host.system.tcp.ListenDrops $stats[22] $now\n";
  push @data, "$server.$host.system.tcp.TCPFastRetrans $stats[46] $now\n";
  push @data, "$server.$host.system.tcp.TCPSlowStartRetrans $stats[48] $now\n";
  push @data, "$server.$host.system.tcp.TCPTimeOuts $stats[49] $now\n";
  push @data, "$server.$host.system.tcp.TCPBacklogDrop $stats[76] $now\n";
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
   push @data, "$server.$host.system.tcp.ActiveOpens $stats[5] $now\n";
   push @data, "$server.$host.system.tcp.PassiveOpens $stats[6] $now\n";
   push @data, "$server.$host.system.tcp.EstabRsts $stats[8] $now\n"; 
   push @data, "$server.$host.system.tcp.InSegs $stats[10] $now\n";
   push @data, "$server.$host.system.tcp.OutSegs $stats[11] $now\n";
   push @data, "$server.$host.system.tcp.RetransSegs $stats[12] $now\n";
   push @data, "$server.$host.system.tcp.OutRst $stats[14] $now\n";  
 }
close(TCP);
}

sub collect_IOStats {
  my @stats;
  open (IOSTAT, "cat /proc/diskstats |")|| die print "failed to get data: $!\n";
  while (<IOSTAT>) {
  next if (/^$/ || /loop/) ;
  @stats = split;
  push @data, "$server.$host.system.io.$stats[2].ReadIOPS $stats[3] $now\n";
  push @data, "$server.$host.system.io.$stats[2].WriteIOPS $stats[7] $now\n";
  push @data, "$server.$host.system.io.$stats[2].ReadSectors  $stats[5]  $now\n";
  push @data, "$server.$host.system.io.$stats[2].WriteSectors $stats[9]  $now\n";
  push @data, "$server.$host.system.io.$stats[2].ReadTime $stats[6] $now\n";
  push @data, "$server.$host.system.io.$stats[2].WriteTime $stats[10] $now\n";
  push @data, "$server.$host.system.io.$stats[2].QueueSize $stats[13] $now\n";
  push @data, "$server.$host.system.io.$stats[2].Utilization $stats[12] $now\n";
 } 
close(IOSTAT);

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

 push @data, "$server.$host.system.mem.free_cached $free_cached $now\n";
 push @data, "$server.$host.system.mem.free_unused $free_unused $now\n";
 push @data, "$server.$host.system.mem.used $used $now\n";
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
  push @data, "$server.$host.system.CPU.$stats[0] $stats[1] $now\n";
 } 
 }
close(MPSTAT);
 foreach $key (keys %cpuhash){
  $user = $cpuhash{$key}[0] + $cpuhash{$key}[1];
  $sys = $cpuhash{$key}[2];
  $idle = $cpuhash{$key}[3] + $cpuhash{$key}[4];
  $intr = $cpuhash{$key}[5];
  $softirq = $cpuhash{$key}[6];
  
  push @data, "$server.$host.system.CPU.$key.user $user $now\n";
  push @data, "$server.$host.system.CPU.$key.sys $sys $now\n";
  push @data, "$server.$host.system.CPU.$key.idle $idle $now\n";
  push @data, "$server.$host.system.CPU.$key.intr $intr $now\n";
  push @data, "$server.$host.system.CPU.$key.softirq $softirq $now\n";
 }
}

#device bastion-efs.us-west-2a.mgmt.netflix.net:/ mounted on /efs with fstype nfs4 statvers=1.1
#device bastion-efs.us-west-2a.mgmt.netflix.net://home mounted on /home with fstype nfs4 statvers=1.1
#device bastion-efs.us-west-2a.mgmt.netflix.net://scratchdata mounted on /scratchdata with fstype nfs4 statvers=1.1
sub collect_NFSiostats {
  my @stats;
  my @mounts;
  open(NFS, "cat /proc/self/mountstats |") || die print "failed to get data: $!\n";
  while (<NFS>) {
  if (/nfs4/){
    s/:/ /g; 
    s/\//mpt-/g;
    #print;
    @mounts=split;
   }
  if (/(READ:|WRITE:|OPEN:|CLOSE:|SETATTR:|LOCK:|ACCESS:|GETATTR:|LOOKUP:|REMOVE:|RENAME:|LINK:|SYMLINK:|CREATE:|STATFS:|READLINK:|READDIR:)/) {
  s/:/ /g;
  @stats = split;
  push @data, "$server.$host.system.nfs.$mounts[5].$stats[0].Ops $stats[1] $now\n";
  push @data, "$server.$host.system.nfs.$mounts[5].$stats[0].Trans $stats[2] $now\n";
  push @data, "$server.$host.system.nfs.$mounts[5].$stats[0].Timeouts $stats[3] $now\n";
  push @data, "$server.$host.system.nfs.$mounts[5].$stats[0].BytesSent $stats[4] $now\n";
  push @data, "$server.$host.system.nfs.$mounts[5].$stats[0].BytesRecv $stats[5] $now\n";
  push @data, "$server.$host.system.nfs.$mounts[5].$stats[0].Queueing $stats[6] $now\n";
  push @data, "$server.$host.system.nfs.$mounts[5].$stats[0].RpcRTT $stats[7] $now\n";
  push @data, "$server.$host.system.nfs.$mounts[5].$stats[0].RpcExec $stats[8] $now\n";
  }
 }
}

sub collect_ETHTool {
  my @stats;
  my @ETH = `ls /sys/class/net/`;
  foreach my $ETH (@ETH){
    next if ($ETH =~ /lo/);
    chomp($ETH);
    open(ETHTOOL, "ethtool -S $ETH |") || die print "failed to get data: $!\n";
     while (<ETHTOOL>) {
      next if (/napi/ || /misses/ || /csum/ || /^NIC/ || /multicast/ || /poll/);
      if (/rx_/ || /tx_/){
      s/:/ /g;
      @stats=split;  
      push @data, "$server.$host.system.ethtool.$ETH.$stats[0] $stats[1] $now\n";
   }
  }
  close(ETHTOOL);
 }
}
