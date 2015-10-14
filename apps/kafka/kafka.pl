#! /usr/bin/perl 

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

open(GRAPHITE, "| nc -w 50 $carbon_server $carbon_port") || die "failed to send: $!\n";

# ------------------------------agent specific sub routines-------------------
sub build_HashArray;
sub collect_HeapGCStats;
sub collect_MsgStats;
sub collect_ReqStats;
sub collect_MiscStats;

my %hash;
my %pchash;
my %jvmhash;
my %cmshash;
my %parhash;
my %thrhash;
my %reqhash;
my $skip = 10;  
my $exit;

my @MemoryTypes = ('HeapMemoryUsage', 'NonHeapMemoryUsage');
my @MemoryUsage = ('max','committed', 'init', 'used');
my @CMS = ('ConcurrentMarkSweep', 'ParNew');
my @Par = ('"PS MarkSweep"', '"PS Scavenge"');
my @G1 = ('"G1 Old Generation"', '"G1 Young Generation"');
my @GCStats = ('CollectionCount', 'CollectionTime');

my $token = `jps|grep Kafka`;
my @pid = split / /, $token;
$exit = `java -jar ../jolokia-jvm-1.2.2-agent.jar start $pid[0] 2>&1`;  # Attaching to JMX port
 if ($exit =~ /Cannot attach/) {
   print "\nfailed to connect to JMX port: $!\n";
   printf "command exited with value %d\n", $? >> 8;
   exit;
 }

# Build hash array for JVM Heap and GC Stats
%jvmhash  = build_HashArray(\@MemoryTypes, \@MemoryUsage);
my $GC;
#$GC= `/bin/ps -p $pid[0] -o command |grep CMS`;
    %cmshash = build_HashArray(\@CMS, \@GCStats);
    %parhash = build_HashArray(\@Par, \@GCStats);
    %g1hash = build_HashArray(\@G1, \@GCStats);

    #%msghash = build_HashArray(\@ThreadPool, \@ThreadStats);
    #%reqhash = build_HashArray(\@ThreadPool, \@requestStats);

while (1) {

 $now = `date +%s`;

 collect_HeapGCStats;
 collect_MsgStats;
 collect_ReqStats;
 collect_MiscStats;

 #print @data; 					# For Testing only 
 #print "\n------\n"; 				# For Testing only
 print GRAPHITE  @data;  			# Ship metrics to carbon server
 @data=();  					# Initialize for next set of metrics

 sleep $interval ;
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
  #return \%sub_hash;   # Return by reference is faster but did not work
  return %sub_hash;
 }

sub collect_HeapGCStats {
 my $results = 0;

 foreach my $key (keys %jvmhash) {
   foreach (@{$jvmhash{$key}}) {
   $results =  `wget -q -O - http://127.0.0.1:8778/jolokia/read/java.lang:type=Memory/$key/$_`;
   $results =~/"value":(\d+)/;
   push @data, "$server.$host.kafka.Memory.$key.$_ $1 $now\n";
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
   push @data, "$server.$host.kafka.Memory.GCDuration.PGC.$pgkey.$parhash{$key}[0] $1 $now\n";

   $results =  `wget -q -O - http://127.0.0.1:8778/jolokia/read/java.lang:type=GarbageCollector,name=$key/$parhash{$key}[1]`;
   $results =~/"value":(\d+)/;
   push @data, "$server.$host.kafka.Memory.GCDuration.PGC.$pgkey.$parhash{$key}[1] $1 $now\n";
   }
  }

 foreach my $key (keys %cmshash) { # cms 
   my $pgkey = $key;
      $pgkey =~ s/"//g;
      $pgkey =~ s/ /-/g;

   $results =  `wget -q -O - http://127.0.0.1:8778/jolokia/read/java.lang:type=GarbageCollector,name=$key/$cmshash{$key}[0]`;
   if ($results !~ /NotFoundException/) { 
   $results =~/"value":(\d+)/;
   push @data, "$server.$host.kafka.Memory.GCDuration.CMS.$pgkey.$cmshash{$key}[0] $1 $now\n";

   $results =  `wget -q -O - http://127.0.0.1:8778/jolokia/read/java.lang:type=GarbageCollector,name=$key/$cmshash{$key}[1]`;
   $results =~/"value":(\d+)/;
   push @data, "$server.$host.kafka.Memory.GCDuration.CMS.$pgkey.$cmshash{$key}[1] $1 $now\n";
   }
  }

 foreach my $key (keys %g1hash) { # G1 
   my $pgkey = $key;
      $pgkey =~ s/"//g;
      $pgkey =~ s/ /-/g;

   $results =  `wget -q -O - http://127.0.0.1:8778/jolokia/read/java.lang:type=GarbageCollector,name=$key/$g1hash{$key}[0]`;
   if ($results !~ /NotFoundException/) {
   $results =~/"value":(\d+)/;
   push @data, "$server.$host.kafka.Memory.GCDuration.CMS.$pgkey.$g1hash{$key}[0] $1 $now\n";

   $results =  `wget -q -O - http://127.0.0.1:8778/jolokia/read/java.lang:type=GarbageCollector,name=$key/$g1hash{$key}[1]`;
   $results =~/"value":(\d+)/;
   push @data, "$server.$host.kafka.Memory.GCDuration.CMS.$pgkey.$g1hash{$key}[1] $1 $now\n";
   }
  }
}

sub collect_MsgStats {
 my @MessageRate = ('MessagesInPerSec', 'BytesInPerSec', 'BytesOutPerSec', 'BytesRejectedPerSec');
 my $results = 0;
 foreach (@MessageRate) { 
  $results = `wget -q -O - http://127.0.0.1:8778/jolokia/read/kafka.server:type=BrokerTopicMetrics,name=$_/Count`;
  if ($results !~ /NotFoundException/) {
     $results =~/"value":(\d+)/;
     push @data, "$server.$host.kafka.MsgRate.$_ $1 $now\n";
   }
 }
}

sub collect_ReqStats {
 my @RequestRate = ('RequestsPerSec', 'TotalTimeMs', 'QueueTimeMs', 'LocalTimeMs', 
						'RemoteTimeMs', 'ResponseSendTimeMs');
 my @RequestType = ('Produce', 'FetchConsumer', 'FetchFollower'); 
 my $results=0;
 my $counter=0;
 foreach $counter (@RequestRate) {
  foreach (@RequestType){
   $results = `wget -q -O - http://127.0.0.1:8778/jolokia/read/kafka.network:type=RequestMetrics,name=$counter,request=$_/Count`;
  if ($results !~ /NotFoundException/) {
     $results =~/"value":(\d+)/;
     push @data, "$server.$host.kafka.ReqRate.$counter.$_ $1 $now\n";
    }
   }
 }
}
 
sub collect_MiscStats {
 $results = 0;
 $results = `wget -q -O - http://127.0.0.1:8778/jolokia/read/kafka.log:type=LogFlushStats,name=LogFlushRateAndTimeMs/Count`;
  if ($results !~ /NotFoundException/) {
     $results =~/"value":(\d+)/;
     push @data, "$server.$host.kafka.LogFlushRate $1 $now\n";
    }
 $results = `wget -q -O - http://127.0.0.1:8778/jolokia/read/kafka.consumer:type=ConsumerFetcherManager,name=MaxLag,clientId=consumer/Value`;
  if ($results !~ /NotFoundException/) {
     $results =~/"value":(\d+)/;
     push @data, "$server.$host.kafka.ConsumerMaxLag $1 $now\n";
    }
 $results = `wget -q -O - http://127.0.0.1:8778/jolokia/read/kafka.server:type=ReplicaFetcherManager,name=MaxLag,clientId=Replica/Value`;
  if ($results !~ /NotFoundException/) {
     $results =~/"value":(\d+)/;
     push @data, "$server.$host.kafka.ReplicaMaxLag $1 $now\n";
    }
}

