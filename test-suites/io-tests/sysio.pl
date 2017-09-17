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

# sysio will be invoked with argumens below:
# ./sysio $same $filesystem 
my ($now, $filesystem) = @ARGV;

# carbon server hostname: example: abyss.us-east-1.test.netflix.net
open(GRAPHITE, "| ../../common/nc -w 25 $carbon_server $carbon_port") || die "failed to send: $!\n";
 
# ------------------------------agent specific sub routines-------------------
sub build_HashArray;
sub collect_NetStats;
sub collect_TCPRetrans;
sub collect_TCPSegs;
sub collect_IOStats;
sub collect_ZFStats;
sub collect_VMStats;
sub collect_CPUStats;
sub collect_NFSiostats;

while (1) {

# Comment out stats that you are not interested in collecting 

 collect_IOStats;			# io stats
 collect_ZFStats;			# zfs stats
 collect_CPUStats;			# cpu stats
 collect_VMStats;			# vm stats
 collect_NFSiostats;			# NFS stats

 #print @data; 				# Testing only 
 #print "\n------\n"; 			# Testing only
 print GRAPHITE @data;			# Ship metrics to graphite server
 @data=();  	

 sleep $interval ;  
 $now = `date +%s`;
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
		
sub collect_IOStats {
  my @stats;
  open (IOSTAT, "cat /proc/diskstats |")|| die print "failed to get data: $!\n";
  while (<IOSTAT>) {
  next if (/^$/ || /loop/) ;
  @stats = split;
  push @data, "$server-iobench.$host.benchmark.IO.$filesystem.system.io.$stats[2].ReadIOPS $stats[3] $now\n";
  push @data, "$server-iobench.$host.benchmark.IO.$filesystem.system.io.$stats[2].WriteIOPS $stats[7] $now\n";
  push @data, "$server-iobench.$host.benchmark.IO.$filesystem.system.io.$stats[2].ReadSectors  $stats[5]  $now\n";
  push @data, "$server-iobench.$host.benchmark.IO.$filesystem.system.io.$stats[2].WriteSectors $stats[9]  $now\n";
  push @data, "$server-iobench.$host.benchmark.IO.$filesystem.system.io.$stats[2].ReadTime $stats[6] $now\n";
  push @data, "$server-iobench.$host.benchmark.IO.$filesystem.system.io.$stats[2].WriteTime $stats[10] $now\n";
  push @data, "$server-iobench.$host.benchmark.IO.$filesystem.system.io.$stats[2].QueueSize $stats[13] $now\n";
  push @data, "$server-iobench.$host.benchmark.IO.$filesystem.system.io.$stats[2].Utilization $stats[12] $now\n";
 } 
close(IOSTAT);
}

#               capacity     operations    bandwidth
#pool        alloc   free   read  write   read  write
#----------  -----  -----  -----  -----  -----  -----
#pool        2.93G  2.18T      0      0      0      0
sub collect_ZFStats {
  my @stats;
  open (ZFSTAT, "sudo zpool iostat -y 2>/dev/null|")|| die print "failed to get data: $!\n";
  while (<ZFSTAT>) {
  if (/^pool/){
  next if (/^$/ || /capacity/ || /alloc/ || /^--/) ;
  @stats = split;
  if ($stats[3] =~ /K/){ $stats[3] = $stats[3] * 1024; } 
  elsif ($stats[3] =~ /M/){ $stats[3] = $stats[3] * 1024 * 1024;} 
  elsif ($stats[3] =~ /G/){ $stats[3] = $stats[3] * 1024 * 1024 * 1024; } 
  if ($stats[4] =~ /K/){ $stats[4] = $stats[4] * 1024; } 
  elsif ($stats[4] =~ /M/){ $stats[4] = $stats[4] * 1024 * 1024; } 
  elsif ($stats[4] =~ /G/){ $stats[4] = $stats[4] * 1024 * 1024 * 1024; } 
  if ($stats[5] =~ /K/){ $stats[5] = $stats[5] * 1024; } 
  elsif ($stats[5] =~ /M/){ $stats[5] = $stats[5] * 1024 * 1024; } 
  elsif ($stats[5] =~ /G/){ $stats[5] = $stats[5] * 1024 * 1024 * 1024; } 
  if ($stats[6] =~ /K/){ $stats[6] = $stats[6] * 1024; } 
  elsif ($stats[6] =~ /M/){ $stats[6] = $stats[6] * 1024 * 1024; } 
  elsif ($stats[6] =~ /G/){ $stats[6] = $stats[6] * 1024 * 1024 * 1024; } 

  push @data, "$server-iobench.$host.benchmark.IO.$filesystem.system.io.$stats[0].ReadIOPS $stats[3] $now\n";
  push @data, "$server-iobench.$host.benchmark.IO.$filesystem.system.io.$stats[0].WriteIOPS $stats[4] $now\n";
  push @data, "$server-iobench.$host.benchmark.IO.$filesystem.system.io.$stats[0].ReadBW $stats[5] $now\n";
  push @data, "$server-iobench.$host.benchmark.IO.$filesystem.system.io.$stats[0].WriteBW $stats[6] $now\n";
  }
 }
close(ZFSTAT);
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

 push @data, "$server-iobench.$host.benchmark.IO.$filesystem.system.mem.free_cached $free_cached $now\n";
 push @data, "$server-iobench.$host.benchmark.IO.$filesystem.system.mem.free_unused $free_unused $now\n";
 push @data, "$server-iobench.$host.benchmark.IO.$filesystem.system.mem.used $used $now\n";
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
  push @data, "$server-iobench.$host.benchmark.IO.$filesystem.system.CPU.$stats[0] $stats[1] $now\n";
 } 
 }
close(MPSTAT);
 foreach $key (keys %cpuhash){
  $user = $cpuhash{$key}[0] + $cpuhash{$key}[1];
  $sys = $cpuhash{$key}[2];
  $idle = $cpuhash{$key}[3] + $cpuhash{$key}[4];
  $intr = $cpuhash{$key}[5];
  $softirq = $cpuhash{$key}[6];
  
  push @data, "$server-iobench.$host.benchmark.IO.$filesystem.system.CPU.$key.user $user $now\n";
  push @data, "$server-iobench.$host.benchmark.IO.$filesystem.system.CPU.$key.sys $sys $now\n";
  push @data, "$server-iobench.$host.benchmark.IO.$filesystem.system.CPU.$key.idle $idle $now\n";
  push @data, "$server-iobench.$host.benchmark.IO.$filesystem.system.CPU.$key.intr $intr $now\n";
  push @data, "$server-iobench.$host.benchmark.IO.$filesystem.system.CPU.$key.softirq $softirq $now\n";
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
    @mounts=split;
   }
  if (/(READ:|WRITE:|OPEN:|CLOSE:|SETATTR:|LOCK:|ACCESS:|GETATTR:|LOOKUP:|REMOVE:|RENAME:|LINK:|SYMLINK:|CREATE:|STATFS:|READLINK:|READDIR:)/) {
  s/:/ /g;
  @stats = split;
  push @data, "$server-iobench.$host.benchmark.IO.$filesystem.system.nfs.$mounts[5].$stats[0].Ops $stats[1] $now\n";
  push @data, "$server-iobench.$host.benchmark.IO.$filesystem.system.nfs.$mounts[5].$stats[0].Trans $stats[2] $now\n";
  push @data, "$server-iobench.$host.benchmark.IO.$filesystem.system.nfs.$mounts[5].$stats[0].Timeouts $stats[3] $now\n";
  push @data, "$server-iobench.$host.benchmark.IO.$filesystem.system.nfs.$mounts[5].$stats[0].BytesSent $stats[4] $now\n";
  push @data, "$server-iobench.$host.benchmark.IO.$filesystem.system.nfs.$mounts[5].$stats[0].BytesRecv $stats[5] $now\n";
  push @data, "$server-iobench.$host.benchmark.IO.$filesystem.system.nfs.$mounts[5].$stats[0].Queueing $stats[6] $now\n";
  push @data, "$server-iobench.$host.benchmark.IO.$filesystem.system.nfs.$mounts[5].$stats[0].RpcRTT $stats[7] $now\n";
  push @data, "$server-iobench.$host.benchmark.IO.$filesystem.system.nfs.$mounts[5].$stats[0].RpcExec $stats[8] $now\n";
  }
 }
}

