#! /usr/bin/perl 

#use warnings;
#use strict;
use Fcntl qw/:flock/;

open SELF, "< $0" or die ;
flock SELF, LOCK_EX | LOCK_NB  or die "Another instance of the same program is already running: $!";

require "../../env.pl";                            # Sets up environment varilables for all agents

#setpriority(0,$$,19);                          # Uncomment if running script at a lower priority

# ------ End of Config options ---

$SIG{INT} = \&signal_handler;
$SIG{TERM} = \&signal_handler;

my @data = ();                                  # array to store metrics
my $now = `date +%s`;                           # metrics are sent with date stamp to graphite server

#open(GRAPHITE, "| ../../common/nc -w 25 $carbon_server $carbon_port") || die "failed to send: $!\n";
open(GRAPHITE, "| ../../common/ncat -i 1000000ms $carbon_server $carbon_port") || die "failed to send: $!\n";

# ------------------------------agent specific sub routines-------------------
sub build_HashArray;
sub build_HashArrayKeysCF;
sub collect_PendingTasks;
sub collect_CoordStats;
sub collect_CFStats;
sub collect_memtableStats;
sub collect_CFmemtableStats;
sub collect_HeapGCStats;
sub collect_SSTableStats;

my %hash;
my %pchash;
my %jvmhash;
my %gchash;
my %g1hash;
my %gpgchash;
my $skip = 10;  
my $exit;

my @MemoryTypes = ('HeapMemoryUsage', 'NonHeapMemoryUsage');
my @MemoryUsage = ('max','committed', 'init', 'used');
my @CMS = ('ConcurrentMarkSweep', 'ParNew');
my @Par = ('"PS MarkSweep"', '"PS Scavenge"');
my @G1 = ('"G1 Old Generation"', '"G1 Young Generation"');
my @GPGC = ('"GPGC New"', '"GPGC Old"');
my @GCStats = ('CollectionCount', 'CollectionTime');

my $token = `jps|egrep "DseDaemon|DseModule"`;
my @pid = split / /, $token;
$exit = `java -jar ../../common/jolokia-jvm-1.2.2-agent.jar start $pid[0] 2>&1`;  # Attaching to JMX port
 if ($exit =~ /Cannot attach/) {
   print "\nfailed to connect to JMX port: $!\n";
   printf "command exited with value %d\n", $? >> 8;
   exit;
 }

# Build hash array for JVM Heap and GC Stats
%jvmhash  = build_HashArray(\@MemoryTypes, \@MemoryUsage);
my $GC;
  %cmshash = build_HashArray(\@CMS, \@GCStats);
  %parhash = build_HashArray(\@Par, \@GCStats);
  %g1hash = build_HashArray(\@G1, \@GCStats);
  %gpgchash = build_HashArray(\@GPGC, \@GCStats);

# Build hash array containing CF for each keyspace
build_HashArrayKeysCF;


while (1) {

 $now = `date +%s`;

 collect_PendingTasks;
 collect_HeapGCStats;
 collect_CoordStats;
 collect_CFStats;
 collect_memtableStats;
 collect_CFmemtableStats;
 collect_SSTableStats;

 #print @data;	 				# For Testing only 
 #print "\n------\n"; 				# For Testing only
 print GRAPHITE  @data;  			# Ship metrics to carbon server
 @data=();  					# Initialize for next set of metrics

 sleep $interval ;
}

# ----------------------- All subroutines -----------------

sub signal_handler {
 `java -jar ../../common/jolokia-jvm-1.2.2-agent.jar --quiet stop $pid[0]`;
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
  #return \%sub_hash;   # Return by reference is faster but did not work
  return %sub_hash;
 }
		
sub build_HashArrayKeysCF {
 my @stats;
 my $key;
 my $values;
# Save KEYSPACE and associated Column Families into hash of arrays
 open (KEYSPACE, "/apps/nfcassandra_server/bin/cqlsh `local-ipv4` 7104 -f ./CF.input |")|| die print "failed: $!\n";
 while (<KEYSPACE>) {
  next if (/^$/ || /^---/ || /^Keyspace system_traces/ || /^Keyspace system/ || /^Keyspace dse_system/ ) ;
  next unless /^Keyspace/;
  @stats =  split;
  $key = $stats[1];
  push @{$hash{$key}};
  while (<KEYSPACE>) {   # reading CF in the KEYSPACE
   last if /^$/;         # Break if empty line is encountered
   next if /^---/;       
   @stats = split;
   foreach $values (@stats) {     # Save all the associated CF in the array pointing to by KEYSPACE hash key.     
   push (@{$hash{$key}}, $values);
   }
  }
 }
close(KEYSPACE);
}

sub collect_PendingTasks {
 my @Compaction_tasks = ('CompletedTasks', 'PendingTasks', 'TotalBytesCompacted');
 my @Task_stages = ('MutationStage', 'ReadRepairStage', 'ReadStage', 'ReplicationOnWriteStage', 'RequestResponseStage');
 my @IntTask_Stages = ('AntiEntropyStage','FlushWriter', 'GossipStage', 'HintedHandoff', 'InternalResponseStage','MemoryMeter','MemtablePostFlusher', 'MigrationStage', 'commitlog_archiver', 'PendingRangeCalculator');
 my @Tasks = ('CompletedTasks', 'PendingTasks', 'ActiveCount', 'CurrentlyBlockedTasks');  
 my $counter = 0;
 my $anothercounter = 0;
 my $results = 0; 

 foreach $counter (@Compaction_tasks) {
   $results =  `wget -q -O - http://127.0.0.1:8778/jolokia/read/org.apache.cassandra.db:type=CompactionManager/$counter`;
   if ($results !~ /NotFoundException/) {
   $results =~/"value":(\d+)/;
   push @data, "$server.$host.cassandra.Compaction.$counter $1 $now\n";
  }
 }
 foreach $counter (@Task_stages) {
  foreach $anothercounter (@Tasks) {
   $results =  `wget -q -O - http://127.0.0.1:8778/jolokia/read/org.apache.cassandra.request:type=$counter/$anothercounter`;
   if ($results !~ /NotFoundException/) {
   $results =~/"value":(\d+)/;
   push @data, "$server.$host.cassandra.$counter.$anothercounter $1 $now\n";
   }
  }
 }
 foreach $counter (@IntTask_Stages) {
  foreach $anothercounter (@Tasks) {
   $results =  `wget -q -O - http://127.0.0.1:8778/jolokia/read/org.apache.cassandra.internal:type=$counter/$anothercounter`;
   if ($results !~ /NotFoundException/) {
   $results =~/"value":(\d+)/;
   push @data, "$server.$host.cassandra.$counter.$anothercounter $1 $now\n";
   }
  }
 }

}
sub collect_HeapGCStats {
 my $results = 0;

 foreach my $key (keys %jvmhash) {
   foreach (@{$jvmhash{$key}}) {
   $results =  `wget -q -O - http://127.0.0.1:8778/jolokia/read/java.lang:type=Memory/$key/$_`;
   if ($results !~ /NotFoundException/) {
   $results =~/"value":(\d+)/;
   push @data, "$server.$host.cassandra.Memory.$key.$_ $1 $now\n";
   }
  }
 }

   # Garbage Collection Stats
 
 foreach my $key (keys %parhash) { # parallel 
   my $pgkey = $key;
      $pgkey =~ s/"//g;
      $pgkey =~ s/ /-/g;
  
   $results =  `wget -q -O - http://127.0.0.1:8778/jolokia/read/java.lang:type=GarbageCollector,name=$key/$parhash{$key}[0]`;
   if ($results !~ /NotFoundException/) { 
   $results =~/"value":(\d+)/;
   push @data, "$server.$host.cassandra.Memory.GCDuration.PGC.$pgkey.$parhash{$key}[0] $1 $now\n";

   $results =  `wget -q -O - http://127.0.0.1:8778/jolokia/read/java.lang:type=GarbageCollector,name=$key/$parhash{$key}[1]`;
   $results =~/"value":(\d+)/;
   push @data, "$server.$host.cassandra.Memory.GCDuration.PGC.$pgkey.$parhash{$key}[1] $1 $now\n";
   }
  }

 foreach my $key (keys %cmshash) { # cms 
   my $pgkey = $key;
      $pgkey =~ s/"//g;
      $pgkey =~ s/ /-/g;

   $results =  `wget -q -O - http://127.0.0.1:8778/jolokia/read/java.lang:type=GarbageCollector,name=$key/$cmshash{$key}[0]`;
   if ($results !~ /NotFoundException/) { 
   $results =~/"value":(\d+)/;
   push @data, "$server.$host.cassandra.Memory.GCDuration.CMS.$pgkey.$cmshash{$key}[0] $1 $now\n";

   $results =  `wget -q -O - http://127.0.0.1:8778/jolokia/read/java.lang:type=GarbageCollector,name=$key/$cmshash{$key}[1]`;
   $results =~/"value":(\d+)/;
   push @data, "$server.$host.cassandra.Memory.GCDuration.CMS.$pgkey.$cmshash{$key}[1] $1 $now\n";
   }
  }

 foreach my $key (keys %g1hash) { # G1 
   my $pgkey = $key;
      $pgkey =~ s/"//g;
      $pgkey =~ s/ /-/g;

   $results =  `wget -q -O - http://127.0.0.1:8778/jolokia/read/java.lang:type=GarbageCollector,name=$key/$g1hash{$key}[0]`;
   if ($results !~ /NotFoundException/) {
   $results =~/"value":(\d+)/;
   push @data, "$server.$host.cassandra.Memory.GCDuration.G1.$pgkey.$g1hash{$key}[0] $1 $now\n";

   $results =  `wget -q -O - http://127.0.0.1:8778/jolokia/read/java.lang:type=GarbageCollector,name=$key/$g1hash{$key}[1]`;
   $results =~/"value":(\d+)/;
   push @data, "$server.$host.cassandra.Memory.GCDuration.G1.$pgkey.$g1hash{$key}[1] $1 $now\n";
   }
  }

 foreach my $key (keys %gpgchash) { # GPGC Zinc Garbage Collector 
   my $pgkey = $key;
      $pgkey =~ s/"//g;
      $pgkey =~ s/ /-/g;

   $results =  `wget -q -O - http://127.0.0.1:8778/jolokia/read/java.lang:type=GarbageCollector,name=$key/$gpgchash{$key}[0]`;
   if ($results !~ /NotFoundException/) {
   $results =~/"value":(\d+)/;
   push @data, "$server.$host.cassandra.Memory.GCDuration.GPGC.$pgkey.$gpgchash{$key}[0] $1 $now\n";

   $results =  `wget -q -O - http://127.0.0.1:8778/jolokia/read/java.lang:type=GarbageCollector,name=$key/$gpgchash{$key}[1]`;
   $results =~/"value":(\d+)/;
   push @data, "$server.$host.cassandra.Memory.GCDuration.GPGC.$pgkey.$gpgchash{$key}[1] $1 $now\n";
   }
  }
}

sub collect_CoordStats {
 my @COOR_OPS = ('WriteOperations', 'ReadOperations');
 my @COOR_LATENCY = ('95thPercentile', '99thPercentile');
 my $counter = 0;
 my $results = 0;

 # Read and Write Ops
 foreach $counter (@COOR_OPS) {
   $results =  `wget -q -O - http://127.0.0.1:8778/jolokia/read/org.apache.cassandra.db:type=StorageProxy/$counter`;
   if ($results !~ /NotFoundException/) {
   $results =~/"value":(\d+)/;
   push @data, "$server.$host.cassandra.Coordinator.$counter $1 $now\n";
  } 
 }
 # Read and Write Latency
 foreach $counter (@COOR_LATENCY) {
   $results =  `wget -q -O - http://127.0.0.1:8778/jolokia/read/org.apache.cassandra.metrics:type=ClientRequest,scope=Read,name=Latency/$counter`;
  if ($results !~ /NotFoundException/) {
   $results =~/"value":(\d+)/;
   push @data, "$server.$host.cassandra.Coordinator.ReadLatency$counter $1 $now\n"; 
  }
   $results =  `wget -q -O - http://127.0.0.1:8778/jolokia/read/org.apache.cassandra.metrics:type=ClientRequest,scope=Write,name=Latency/$counter`;
   if ($results !~ /NotFoundException/) {
   $results =~/"value":(\d+)/;
   push @data, "$server.$host.cassandra.Coordinator.WriteLatency$counter $1 $now\n";
   }
  }
}

sub collect_CFStats {
 my @CF_OPS =  ('WriteCount', 'ReadCount'); 
 my @CF_LATENCY = ('95thPercentile', '99thPercentile');
 my $counter = 0;
 my $anothercounter = 0;
 my $results = 0;
 my $key = 0;

 # Read and Write Ops 
 foreach $counter (@CF_OPS) {
  foreach $key (keys %hash) {  # key is the KEYSPACE
   foreach (@{$hash{$key}}) {  # value is all CF in the KEYSPACE
    $results = `wget -q -O - http://127.0.0.1:8778/jolokia/read/org.apache.cassandra.db:type=ColumnFamilies,keyspace=$key,columnfamily=$_/$counter`;
    if ($results !~ /NotFoundException/) {
    $results =~/"value":(\d+)/;
    push @data, "$server.$host.cassandra.ColumnFamilies.$key.$_.$counter $1 $now\n";
   }
  }
 }
 }
 # Read and Write Latencies 
 foreach $counter (@CF_LATENCY) {
  foreach my $key (keys %hash) {  # key is the KEYSPACE
   foreach (@{$hash{$key}}) {  # value is all CF in the KEYSPACE
    $results =  `wget -q -O - http://127.0.0.1:8778/jolokia/read/org.apache.cassandra.metrics:type=ColumnFamily,keyspace=$key,scope=$_,name=ReadLatency/$counter`;
   if ($results !~ /NotFoundException/) {
    $results =~/"value":(\d+)/;
    push @data, "$server.$host.cassandra.ColumnFamilies.$key.$_.ReadLatency$counter $1 $now\n";
   }
    $results =  `wget -q -O - http://127.0.0.1:8778/jolokia/read/org.apache.cassandra.metrics:type=ColumnFamily,keyspace=$key,scope=$_,name=WriteLatency/$counter`;
    if ($results !~ /NotFoundException/) {
    $results =~/"value":(\d+)/;
    push @data, "$server.$host.cassandra.ColumnFamilies.$key.$_.WriteLatency$counter $1 $now\n";
    }
   }
  }
 }
}
sub collect_CFmemtableStats {
 my @MEMTABLE =  ('MemtableDataSize', 'MemtableColumnsCount', 'LiveSSTableCount');
 my $counter = 0;
 my $results = 0;
 foreach $counter (@MEMTABLE) {
  foreach my $key (keys %hash) {  # key is the KEYSPACE
   foreach (@{$hash{$key}}) {  # value is all CF in the KEYSPACE
    $results =  `wget -q -O - http://127.0.0.1:8778/jolokia/read/org.apache.cassandra.metrics:type=ColumnFamily,keyspace=$key,scope=$_,name=$counter`;
    if ($results !~ /NotFoundException/) {
    $results =~/"Value":(\d+)/;
    push @data, "$server.$host.cassandra.Memtable.ColumnFamilies.$key.$_.$counter $1 $now\n";
    }
   }
  }
 }
  foreach my $key (keys %hash) {  # key is the KEYSPACE
   foreach (@{$hash{$key}}) {  # value is all CF in the KEYSPACE
    $results =  `wget -q -O - http://127.0.0.1:8778/jolokia/read/org.apache.cassandra.metrics:type=ColumnFamily,keyspace=$key,scope=$_,name=MemtableSwitchCount`;
    if ($results !~ /NotFoundException/) {
    $results =~/"Count":(\d+)/;
    push @data, "$server.$host.cassandra.Memtable.ColumnFamilies.$key.$_.MemtableSwitchCount $1 $now\n";
    } 
   }
  }
}

sub collect_memtableStats {
 my @MEMTABLE =  ('MemtableDataSize', 'MemtableColumnsCount', 'MemtableSwitchCount', 'LiveSSTableCount');
 my $counter = 0;
 my $results = 0;

# value":{"Value"
 foreach $counter (@MEMTABLE) {
   $results =  `wget -q -O - http://127.0.0.1:8778/jolokia/read/org.apache.cassandra.metrics:type=ColumnFamily,name=$counter`;
   if ($results !~ /NotFoundException/) {
   $results =~/"Value":(\d+)/;
   push @data, "$server.$host.cassandra.Memtable.$counter $1 $now\n";
   }
 }
}
sub collect_SSTableStats {
 my $size;
 my $percent;
 my @stats;
 my $key; 
 my $file;
 my $start;
 my $count;
 if ($skip < 10) {  # capturing SSTable caching stats is resource intensive. Skip it for next 10 iterations
  $count = `ls /mnt/data/cassandra070/data/*/*/*-Data.db|wc -l`;
  chomp($count);
  push @data, "$server.$host.cassandra.cachedSSTABLES.count $count $now\n";
  foreach $key (keys %pchash) {
   # Ship the cached stats. Don't collect new one
    push @data, "$server.$host.cassandra.cachedSSTABLES.$key.size $pchash{$key}[0] $now\n";
    push @data, "$server.$host.cassandra.cachedSSTABLES.$key.percent $pchash{$key}[1] $now\n";
      }
   $skip = $skip + 1;
 }
 else {   # collect a new stat
   open (PCSTAT, "../../common/pcstat -json /mnt/data/cassandra070/data/*/*/*-Data.db | json_pp |")|| die print "failed to get data: $!\n";
   while (<PCSTAT>) {
    next if /^$/;
    s/\{//g;  # trim {
    s/\}//g;  # trim }
    s/\]//g;  # trim ]
    s/\[//g;  # trim [
    s/,//g;   # trim ,
    s/"//g;   # trim ""
    s/^\s+|\s+$//g;   # trim white space from both ends
    @stats = split ":";
    $size = $stats[1] if ($stats[0] =~ /size/);
    $percent = $stats[1] if ($stats[0] =~ /percent/);
    if ($stats[0] =~ /filename/){
        $start = rindex($stats[1], "/");
        $start += 1;
        $file = substr($stats[1], $start);

        # Cache it in hash of arrays for later use.
        push (@{$pchash{$file}}, $size, $percent );

        # push it to the server
        push @data, "$server.$host.cassandra.cachedSSTABLES.$file.size $size $now\n";
        push @data, "$server.$host.cassandra.cachedSSTABLES.$file.percent $percent $now\n";
     }
  }
 close(PCSTAT);

 $count = `ls /mnt/data/cassandra070/data/*/*/*-Data.db|wc -l`;
 chomp($count);
 push @data, "$server.$host.cassandra.cachedSSTABLES.count $count $now\n";

 $skip = 0;
 } 
}