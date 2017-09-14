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
sub collect_TCPInfo;
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
 collect_TCPInfo;
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
  next if (/^$/ || /^Inter/ || /face/ || /lo:/) ;
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
  push @data, "$server.$host.system.tcp.ListenDrops $stats[21] $now\n";
  push @data, "$server.$host.system.tcp.TCPFastRetrans $stats[45] $now\n";
  push @data, "$server.$host.system.tcp.TCPSlowStartRetrans $stats[47] $now\n";
  push @data, "$server.$host.system.tcp.TCPTimeOuts $stats[48] $now\n";
  push @data, "$server.$host.system.tcp.TCPBacklogDrop $stats[76] $now\n";
 }
close(TCP);
}

# Useful for network throughput test performed using netperf with port 7421. Otherwise change it
sub collect_TCPInfo {
#Netid  State      Recv-Q Send-Q Local Address:Port                 Peer Address:Port
#tcp    ESTAB      0      9369024 100.66.47.109:7421                 100.66.2.184:7421
# cubic wscale:9,9 rto:204 rtt:0.593/0.029 mss:1344 cwnd:401 ssthresh:267 bytes_acked:165908342209 segs_out:123447072 segs_in:9298694 send 7270.7Mbps 
# lastrcv:282920 pacing_rate 8721.2Mbps unacked:251 retrans:0/3112 rcv_space:2688
#Netid  State      Recv-Q Send-Q                        Local Address:Port                                         Peer Address:Port                
#tcp    ESTAB      0      11104128                        100.66.47.109:7421                                         100.66.2.184:7421                 
#	 bbr wscale:9,9 rto:204 rtt:0.626/0.027 mss:1344 cwnd:432 bytes_acked:969231544513 segs_out:721170953 segs_in:60474955 send 7419.9Mbps lastrcv:1649180 pacing_rate 6508.8Mbps unacked:246 retrans:0/16246 rcv_space:27120

my @stats;
open (TCP, "ss -i '( dport = :7421 )' |")|| die print "failed to get data: $!\n";
while (<TCP>) {
  next if (/Netid/);
  next if /^\s*$/;
  @stats = split;
   if ( /^tcp/ ) {
    push @data, "$server.$host.system.tcp.tcpinfo.Recv-Q $stats[2] $now\n";
    push @data, "$server.$host.system.tcp.tcpinfo.Send-Q $stats[3] $now\n";
   }
  else {
	@rto = split /:/, $stats[2];
        push @data, "$server.$host.system.tcp.tcpinfo.$stats[0].$rto[0] $rto[1] $now\n";

        @rtt = split /:/, $stats[3];
   	@rttext = split /\//, $rtt[1];
        push @data, "$server.$host.system.tcp.tcpinfo.$stats[0].$rtt[0].RTT $rttext[0] $now\n";
        push @data, "$server.$host.system.tcp.tcpinfo.$stats[0].$rtt[0].RTTVAR $rttext[1] $now\n";

	@mss = split /:/, $stats[4];
        push @data, "$server.$host.system.tcp.tcpinfo.$stats[0].$mss[0] $mss[1] $now\n";

  	@cwnd = split /:/, $stats[5];
        push @data, "$server.$host.system.tcp.tcpinfo.$stats[0].$cwnd[0] $cwnd[1] $now\n";

  	@ssth = split /:/, $stats[6];
        push @data, "$server.$host.system.tcp.tcpinfo.$stats[0].$ssth[0] $ssth[1] $now\n";

	$stats[10] =~ s/Mbps//;
        push @data, "$server.$host.system.tcp.tcpinfo.$stats[0].$stats[9] $stats[10] $now\n";

	@retrans = split /:/, $stats[15];
  	@retransext = split /\//, $retrans[1];
        push @data, "$server.$host.system.tcp.tcpinfo.$stats[0].$retrans[0].RETRANS $retransext[0] $now\n";
        push @data, "$server.$host.system.tcp.tcpinfo.$stats[0].$retrans[0].RETRANSDIVIDER $retransext[1] $now\n";

	@rcv = split /:/, $stats[16];
        push @data, "$server.$host.system.tcp.tcpinfo.$stats[0].$rcv[0] $rcv[1] $now\n";

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
  next if (/^$/ || /loop/ || /ram/) ;
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

 open(VMSTAT, "head -5 /proc/meminfo |")|| die print "failed to get data: $!\n";
 while (<VMSTAT>) {
 next if (/^$/);
 s/://g;   # trim ":"
 @stats = split;
 push @Array,$stats[1];
 }
close (VMSTAT);
 $free_cached = $Array[3] + $Array[4];
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
  $steal = $cpuhash{$key}[7];  
  push @data, "$server.$host.system.CPU.$key.user $user $now\n";
  push @data, "$server.$host.system.CPU.$key.sys $sys $now\n";
  push @data, "$server.$host.system.CPU.$key.idle $idle $now\n";
  push @data, "$server.$host.system.CPU.$key.intr $intr $now\n";
  push @data, "$server.$host.system.CPU.$key.softirq $softirq $now\n";
  push @data, "$server.$host.system.CPU.$key.steal $steal $now\n";
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
 open(NFSOPS, "cat /proc/net/rpc/nfs |") || die print "failed to get data: $!\n";
 while(<NFSOPS>) {
 if (/net/){
    @stats=split;
    push @data, "$server.$host.system.nfs.$stats[0].packets $stats[1] $now\n";
    push @data, "$server.$host.system.nfs.$stats[0].tcpcnt $stats[2] $now\n";
    push @data, "$server.$host.system.nfs.$stats[0].tcpconn $stats[3] $now\n";
    push @data, "$server.$host.system.nfs.$stats[0].udpcnt $stats[4] $now\n";
   } 
 elsif (/rpc/){
    @stats=split;
    push @data, "$server.$host.system.nfs.$stats[0].authrefrsh $stats[1] $now\n";
    push @data, "$server.$host.system.nfs.$stats[0].calls $stats[2] $now\n";
    push @data, "$server.$host.system.nfs.$stats[0].retrans $stats[3] $now\n";
   }
 elsif (/proc4/){
    @stats=split;
    push @data, "$server.$host.system.nfs.$stats[0].access $stats[1] $now\n";
    push @data, "$server.$host.system.nfs.$stats[0].close $stats[2] $now\n";
    push @data, "$server.$host.system.nfs.$stats[0].commit $stats[3] $now\n";
    push @data, "$server.$host.system.nfs.$stats[0].confirm $stats[4] $now\n";
    push @data, "$server.$host.system.nfs.$stats[0].create $stats[5] $now\n";
    push @data, "$server.$host.system.nfs.$stats[0].delegreturn $stats[6] $now\n";
    push @data, "$server.$host.system.nfs.$stats[0].fs_locations $stats[7] $now\n";
    push @data, "$server.$host.system.nfs.$stats[0].fsinfo $stats[8] $now\n";
    push @data, "$server.$host.system.nfs.$stats[0].getacl $stats[9] $now\n";
    push @data, "$server.$host.system.nfs.$stats[0].getattr $stats[10] $now\n";
    push @data, "$server.$host.system.nfs.$stats[0].link $stats[11] $now\n";
    push @data, "$server.$host.system.nfs.$stats[0].lock $stats[12] $now\n";
    push @data, "$server.$host.system.nfs.$stats[0].lockt $stats[13] $now\n";
    push @data, "$server.$host.system.nfs.$stats[0].locku $stats[14] $now\n";
    push @data, "$server.$host.system.nfs.$stats[0].lookup $stats[15] $now\n";
    push @data, "$server.$host.system.nfs.$stats[0].lookup_root $stats[16] $now\n";
    push @data, "$server.$host.system.nfs.$stats[0].null $stats[17] $now\n";
    push @data, "$server.$host.system.nfs.$stats[0].open $stats[18] $now\n";
    push @data, "$server.$host.system.nfs.$stats[0].open_conf $stats[19] $now\n";
    push @data, "$server.$host.system.nfs.$stats[0].open_dgrd $stats[20] $now\n";
    push @data, "$server.$host.system.nfs.$stats[0].open_noat $stats[21] $now\n";
    push @data, "$server.$host.system.nfs.$stats[0].pathconf $stats[22] $now\n";
    push @data, "$server.$host.system.nfs.$stats[0].read $stats[23] $now\n";
    push @data, "$server.$host.system.nfs.$stats[0].readdir $stats[24] $now\n";
    push @data, "$server.$host.system.nfs.$stats[0].readlink $stats[25] $now\n";
    push @data, "$server.$host.system.nfs.$stats[0].rel_lkowner $stats[26] $now\n";
    push @data, "$server.$host.system.nfs.$stats[0].remove $stats[27] $now\n";
    push @data, "$server.$host.system.nfs.$stats[0].rename $stats[28] $now\n";
    push @data, "$server.$host.system.nfs.$stats[0].renew $stats[29] $now\n";
    push @data, "$server.$host.system.nfs.$stats[0].server_caps $stats[30] $now\n";
    push @data, "$server.$host.system.nfs.$stats[0].setacl $stats[31] $now\n";
    push @data, "$server.$host.system.nfs.$stats[0].setattr $stats[32] $now\n";
    push @data, "$server.$host.system.nfs.$stats[0].setclntid $stats[33] $now\n";
    push @data, "$server.$host.system.nfs.$stats[0].statfs $stats[34] $now\n";
    push @data, "$server.$host.system.nfs.$stats[0].symlink $stats[35] $now\n";
    push @data, "$server.$host.system.nfs.$stats[0].write $stats[36] $now\n";
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
      if (/tx_bytes/){
      s/:/ /g;
      @stats=split;  
      push @data, "$server.$host.system.ethtool.$ETH.tput.$stats[0] $stats[1] $now\n";
   }
      if (/rx_bytes/){
      s/:/ /g;
      @stats=split;  
      push @data, "$server.$host.system.ethtool.$ETH.rput.$stats[0] $stats[1] $now\n";
   }
      if (/tx_cnt/ || m/tx_queue_([0-9])_packets/){
      s/:/ /g;
      @stats=split;  
      push @data, "$server.$host.system.ethtool.$ETH.tpackets.$stats[0] $stats[1] $now\n";
   }
      if (/rx_cnt/ || m/rx_queue_([0-9])_packets/){
      s/:/ /g;
      @stats=split;  
      push @data, "$server.$host.system.ethtool.$ETH.rpackets.$stats[0] $stats[1] $now\n";
   }
  }
  close(ETHTOOL);
 }
}

