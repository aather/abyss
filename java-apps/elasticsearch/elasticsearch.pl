#! /usr/bin/perl 

#use warnings;
#use strict;
use Fcntl qw/:flock/;
use JSON;

open SELF, "< $0" or die ;
flock SELF, LOCK_EX | LOCK_NB  or die "Another instance of the same program is already running: $!";

require "../../env.pl";                            # Sets up environment varilables for all agents

#setpriority(0,$$,19);                          # Uncomment if running script at a lower priority

# ------ End of Config options ---

my @data = ();                                  # array to store metrics
my $now = `date +%s`;                           # metrics are sent with date stamp to graphite server
my $localIP = $ENV{'EC2_LOCAL_IPV4'};		# metrics for this host only

open(GRAPHITE, "| ../../common/nc -w 50 $carbon_server $carbon_port") || die "failed to send: $!\n";

# ------------------------------agent specific sub routines-------------------
sub build_HashArray;
sub collect_HeapGCStats;
sub collect_IndexStats;

my %hash;
my %pchash;
my %jvmhash;
my %gchash;
my %g1hash;
my %gpgchash;
my $skip = 10;  
my $exit;
my $json;

my $node;
my $curl = `curl -s 'localhost:7104/_cat/nodes?h=id,ip'|grep $localIP`;
my @curl = split/\s+/,$curl;
my $nodeid = $curl[0];

while (1) {

 $now = `date +%s`;

 `curl -s 'localhost:7104/_nodes/stats?pretty=tue' > /tmp/nodestats-pretty.json`;
 `sudo cp /tmp/nodestats-pretty.json .`;
  open (NODEID, "nodestats-pretty.json")|| die print "failed to get data: $!\n";
  while (<NODEID>) {
   next unless /$nodeid/;
   $node = $_;
   $node =~ s/^\s+|\s+$|\"|\{|:|\/|\[//g;
   $node =~ s/^\s+|\s+$//g;
}
close (NODEID);

# Reading json file into $json variable
{
 local $/;
 open my $fh, "<", "nodestats-pretty.json";
 $json = <$fh>;  # read the whole file into $json 
 close $fh;
}

 collect_IndexStats;

 #print @data;	 				# For Testing only 
 #print "\n------\n"; 				# For Testing only
 print GRAPHITE  @data;  			# Ship metrics to carbon server
 @data=();  					# Initialize for next set of metrics

 sleep $interval ;
}

# ----------------------- All subroutines -----------------
# https://www.elastic.co/guide/en/elasticsearch/guide/current/_monitoring_individual_nodes.html
sub collect_IndexStats {
 # indices stats
my $jsondata = decode_json($json);
my $indicesCount = $jsondata->{'nodes'}->{$node}->{'indices'}->{'docs'}->{'count'};
my $indicesStorage = $jsondata->{'nodes'}->{$node}->{'indices'}->{'store'}->{'size_in_bytes'};
my $indicesThrottle = $jsondata->{'nodes'}->{$node}->{'indices'}->{'store'}->{'throttle_time_in_millis'};
push @data, "$server.$host.elasticsearch.indexstats.indicesCount $indicesCount $now\n";
push @data, "$server.$host.elasticsearch.indexstats.indicesStorage $indicesStorage $now\n";
push @data, "$server.$host.elasticsearch.indexstats.indicesThrottle $indicesThrottle $now\n";

# index rate
my $indexTotal = $jsondata->{'nodes'}->{$node}->{'indices'}->{'indexing'}->{'index_total'};
my $indexTime =  $jsondata->{'nodes'}->{$node}->{'indices'}->{'indexing'}->{'index_time_in_millis'};
my $indexPerSecond; 
if ($indexTime > 0) {
   $indexPerSecond =  $indexTotal/$indexTime  ; 
 }
else  { $indexPerSecond = 0; }

my $indexCurrent = $jsondata->{'nodes'}->{$node}->{'indices'}->{'indexing'}->{'index_current'};
my $indexIsThrottled = $jsondata->{'nodes'}->{$node}->{'indices'}->{'indexing'}->{'is_throttled'};
my $indexThrottle = $jsondata->{'nodes'}->{$node}->{'indices'}->{'indexing'}->{'throttle_time_in_millis'};
push @data, "$server.$host.elasticsearch.indexstats.indexRate.indexTotal $indexTotal $now\n";
push @data, "$server.$host.elasticsearch.indexstats.indexRate.indexTime $indexTime $now\n";
push @data, "$server.$host.elasticsearch.indexstats.indexRate.indexPerSecond $indexPerSecond $now\n";
push @data, "$server.$host.elasticsearch.indexstats.indexRate.indexCurrent $indexCurrent $now\n";

push @data, "$server.$host.elasticsearch.indexstats.indexRate.indexIsThrottled $indexIsThrottled $now\n" if ($indexIsThrottled > 0);
push @data, "$server.$host.elasticsearch.indexstats.indexRate.indexThrottle $indexThrottle $now\n" if ($indexThrottle > 0 );

# search rate
my $queryActive = $jsondata->{'nodes'}->{$node}->{'indices'}->{'search'}->{'openContext'};
my $queryTotal = $jsondata->{'nodes'}->{$node}->{'indices'}->{'search'}->{'query_total'};
my $queryTime =  $jsondata->{'nodes'}->{$node}->{'indices'}->{'search'}->{'query_time_in_millis'};
my $queryPerSecond;
if ($queryTime > 0) {
   $queryPerSecond =  $queryTotal/$queryTime  ;
 }
else  { $queryPerSecond = 0; }
my $queryCurrent = $jsondata->{'nodes'}->{$node}->{'indices'}->{'search'}->{'query_current'};

my $fetchTotal = $jsondata->{'nodes'}->{$node}->{'indices'}->{'search'}->{'fetch_total'};
my $fetchTime = $jsondata->{'nodes'}->{$node}->{'indices'}->{'search'}->{'fetch_time_in_millis'};
my $fetchPerSecond;
if ($fetchTime > 0) {
   $fetchPerSecond =  $fetchTotal/$fetchTime  ;
 }
else  { $fetchPerSecond = 0; }
my $fetchCurrent = $jsondata->{'nodes'}->{$node}->{'indices'}->{'search'}->{'fetch_current'};

if ($queryActive > 0) {
push @data, "$server.$host.elasticsearch.indexstats.queryRate.queryActive $queryActive $now\n";
}
else { 
push @data, "$server.$host.elasticsearch.indexstats.queryRate.queryActive 0 $now\n";
}
push @data, "$server.$host.elasticsearch.indexstats.queryRate.queryTotal $queryTotal $now\n";
push @data, "$server.$host.elasticsearch.indexstats.queryRate.queryTime $queryTime $now\n";
push @data, "$server.$host.elasticsearch.indexstats.queryRate.queryPerSecond $queryPerSecond $now\n";
push @data, "$server.$host.elasticsearch.indexstats.queryRate.queryCurrent $queryCurrent $now\n";

push @data, "$server.$host.elasticsearch.indexstats.fetchRate.fetchTotal $fetchTotal $now\n";
push @data, "$server.$host.elasticsearch.indexstats.fetchRate.fetchTime $fetchTime $now\n";
push @data, "$server.$host.elasticsearch.indexstats.fetchRate.fetchPerSecond $fetchPerSecond $now\n";
push @data, "$server.$host.elasticsearch.indexstats.fetchRate.fetchCurrent $fetchCurrent $now\n";


# refresh Rate
my $refreshTotal = $jsondata->{'nodes'}->{$node}->{'indices'}->{'refresh'}->{'total'};
my $refreshTime = $jsondata->{'nodes'}->{$node}->{'indices'}->{'refresh'}->{'total_time_in_millis'};
my $refershPerSecond;
if ($refreshTime > 0) {
   $refreshPerSecond =  $refreshTotal/$refreshTime  ;
 }
else  { $refreshPerSecond = 0; }

push @data, "$server.$host.elasticsearch.indexstats.refreshRate.refreshTotal $refreshTotal $now\n";
push @data, "$server.$host.elasticsearch.indexstats.refreshRate.refreshTime $refreshTime $now\n";
push @data, "$server.$host.elasticsearch.indexstats.refreshRate.refreshPerSecond $refreshPerSecond $now\n";


# flush Rate
my $flushTotal = $jsondata->{'nodes'}->{$node}->{'indices'}->{'flush'}->{'total'};
my $flushTime = $jsondata->{'nodes'}->{$node}->{'indices'}->{'flush'}->{'total_time_in_millis'};
my $flushPerSecond;
if ($flushTime > 0) {
   $flushPerSecond =  $flushTotal/$flushTime  ;
 }
else  { $flushPerSecond = 0; }

push @data, "$server.$host.elasticsearch.indexstats.flushRate.flushTotal $flushTotal $now\n";
push @data, "$server.$host.elasticsearch.indexstats.flushRate.flushTime $flushTime $now\n";
push @data, "$server.$host.elasticsearch.indexstats.flushRate.flushPerSecond $flushPerSecond $now\n";

# index thread poool stats
my $indexThreads = $jsondata->{'nodes'}->{$node}->{'thread_pool'}->{'index'}->{'threads'};
my $indexThreadsQueue = $jsondata->{'nodes'}->{$node}->{'thread_pool'}->{'index'}->{'queue'};
my $indexThreadsActive = $jsondata->{'nodes'}->{$node}->{'thread_pool'}->{'index'}->{'active'};
my $indexThreadsRejected = $jsondata->{'nodes'}->{$node}->{'thread_pool'}->{'index'}->{'rejected'};
my $indexThreadsLargest = $jsondata->{'nodes'}->{$node}->{'thread_pool'}->{'index'}->{'largest'};
my $indexThreadsCompleted = $jsondata->{'nodes'}->{$node}->{'thread_pool'}->{'index'}->{'completed'};

push @data, "$server.$host.elasticsearch.indexstats.indexpool.indexThreads $indexThreads $now\n";
push @data, "$server.$host.elasticsearch.indexstats.indexpool.indexThreadsQueue $indexThreadsQueue $now\n";
push @data, "$server.$host.elasticsearch.indexstats.indexpool.indexThreadsActive $indexThreadsActive $now\n";
push @data, "$server.$host.elasticsearch.indexstats.indexpool.indexThreadsRejected $indexThreadsRejected $now\n";
push @data, "$server.$host.elasticsearch.indexstats.indexpool.indexThreadsLargest $indexThreadsLargest $now\n";
push @data, "$server.$host.elasticsearch.indexstats.indexpool.indexThreadsCompleted $indexThreadsCompleted $now\n";

# search thread poool stats
my $searchThreads = $jsondata->{'nodes'}->{$node}->{'thread_pool'}->{'search'}->{'threads'};
my $searchThreadsQueue = $jsondata->{'nodes'}->{$node}->{'thread_pool'}->{'search'}->{'queue'};
my $searchThreadsActive = $jsondata->{'nodes'}->{$node}->{'thread_pool'}->{'search'}->{'active'};
my $searchThreadsRejected = $jsondata->{'nodes'}->{$node}->{'thread_pool'}->{'search'}->{'rejected'};
my $searchThreadsLargest = $jsondata->{'nodes'}->{$node}->{'thread_pool'}->{'search'}->{'largest'};
my $searchThreadsCompleted = $jsondata->{'nodes'}->{$node}->{'thread_pool'}->{'search'}->{'completed'};

push @data, "$server.$host.elasticsearch.indexstats.searchpool.searchThreads $searchThreads $now\n";
push @data, "$server.$host.elasticsearch.indexstats.searchpool.searchThreadsQueue $searchThreadsQueue $now\n";
push @data, "$server.$host.elasticsearch.indexstats.searchpool.searchThreadsActive $searchThreadsActive $now\n";
push @data, "$server.$host.elasticsearch.indexstats.searchpool.searchThreadsRejected $searchThreadsRejected $now\n";
push @data, "$server.$host.elasticsearch.indexstats.searchpool.searchThreadsLargest $searchThreadsLargest $now\n";
push @data, "$server.$host.elasticsearch.indexstats.searchpool.searchThreadsCompleted $searchThreadsCompleted $now\n";


# bulk thread pool stats
my $bulkThreads = $jsondata->{'nodes'}->{$node}->{'thread_pool'}->{'bulk'}->{'threads'};
my $bulkThreadsQueue = $jsondata->{'nodes'}->{$node}->{'thread_pool'}->{'bulk'}->{'queue'};
my $bulkThreadsActive = $jsondata->{'nodes'}->{$node}->{'thread_pool'}->{'bulk'}->{'active'};
my $bulkThreadsRejected = $jsondata->{'nodes'}->{$node}->{'thread_pool'}->{'bulk'}->{'rejected'};
my $bulkThreadsLargest = $jsondata->{'nodes'}->{$node}->{'thread_pool'}->{'bulk'}->{'largest'};
my $bulkThreadsCompleted = $jsondata->{'nodes'}->{$node}->{'thread_pool'}->{'bulk'}->{'completed'};

push @data, "$server.$host.elasticsearch.indexstats.bulkpool.bulkThreads $bulkThreads $now\n";
push @data, "$server.$host.elasticsearch.indexstats.bulkpool.bulkThreadsQueue $bulkThreadsQueue $now\n";
push @data, "$server.$host.elasticsearch.indexstats.bulkpool.bulkThreadsActive $bulkThreadsActive $now\n";
push @data, "$server.$host.elasticsearch.indexstats.bulkpool.bulkThreadsRejected $bulkThreadsRejected $now\n";
push @data, "$server.$host.elasticsearch.indexstats.bulkpool.bulkThreadsLargest $bulkThreadsLargest $now\n";
push @data, "$server.$host.elasticsearch.indexstats.bulkpool.bulkThreadsCompleted $bulkThreadsCompleted $now\n";

# flush thread pool stats
my $flushThreads = $jsondata->{'nodes'}->{$node}->{'thread_pool'}->{'flush'}->{'threads'};
my $flushThreadsQueue = $jsondata->{'nodes'}->{$node}->{'thread_pool'}->{'flush'}->{'queue'};
my $flushThreadsActive = $jsondata->{'nodes'}->{$node}->{'thread_pool'}->{'flush'}->{'active'};
my $flushThreadsRejected = $jsondata->{'nodes'}->{$node}->{'thread_pool'}->{'flush'}->{'rejected'};
my $flushThreadsLargest = $jsondata->{'nodes'}->{$node}->{'thread_pool'}->{'flush'}->{'largest'};
my $flushThreadsCompleted = $jsondata->{'nodes'}->{$node}->{'thread_pool'}->{'flush'}->{'completed'};

push @data, "$server.$host.elasticsearch.indexstats.flushpool.flushThreads $flushThreads $now\n";
push @data, "$server.$host.elasticsearch.indexstats.flushpool.flushThreadsQueue $flushThreadsQueue $now\n";
push @data, "$server.$host.elasticsearch.indexstats.flushpool.flushThreadsActive $flushThreadsActive $now\n";
push @data, "$server.$host.elasticsearch.indexstats.flushpool.flushThreadsRejected $flushThreadsRejected $now\n";
push @data, "$server.$host.elasticsearch.indexstats.flushpool.flushThreadsLargest $flushThreadsLargest $now\n";
push @data, "$server.$host.elasticsearch.indexstats.flushpool.flushThreadsCompleted $flushThreadsCompleted $now\n";

#  refresh thread pool stats
my $refreshThreads = $jsondata->{'nodes'}->{$node}->{'thread_pool'}->{'refresh'}->{'threads'};
my $refreshThreadsQueue = $jsondata->{'nodes'}->{$node}->{'thread_pool'}->{'refresh'}->{'queue'};
my $refreshThreadsActive = $jsondata->{'nodes'}->{$node}->{'thread_pool'}->{'refresh'}->{'active'};
my $refreshThreadsRejected = $jsondata->{'nodes'}->{$node}->{'thread_pool'}->{'refresh'}->{'rejected'};
my $refreshThreadsLargest = $jsondata->{'nodes'}->{$node}->{'thread_pool'}->{'refresh'}->{'largest'};
my $refreshThreadsCompleted = $jsondata->{'nodes'}->{$node}->{'thread_pool'}->{'refresh'}->{'completed'};

push @data, "$server.$host.elasticsearch.indexstats.refreshpool.refreshThreads $refreshThreads $now\n";
push @data, "$server.$host.elasticsearch.indexstats.refreshpool.refreshThreadsQueue $refreshThreadsQueue $now\n";
push @data, "$server.$host.elasticsearch.indexstats.refreshpool.refreshThreadsActive $refreshThreadsActive $now\n";
push @data, "$server.$host.elasticsearch.indexstats.refreshpool.refreshThreadsRejected $refreshThreadsRejected $now\n";
push @data, "$server.$host.elasticsearch.indexstats.refreshpool.refreshThreadsLargest $refreshThreadsLargest $now\n";
push @data, "$server.$host.elasticsearch.indexstats.refreshpool.refreshThreadsCompleted $refreshThreadsCompleted $now\n";

# merges
my $mergeCurrent = $jsondata->{'nodes'}->{$node}->{'indices'}->{'merges'}->{'current'};
my $mergeCurrentDocs = $jsondata->{'nodes'}->{$node}->{'indices'}->{'merges'}->{'current_docs'};
my $mergeCurrentSize = $jsondata->{'nodes'}->{$node}->{'indices'}->{'merges'}->{'current_size_in_bytes'};
my $mergeTotal = $jsondata->{'nodes'}->{$node}->{'indices'}->{'merges'}->{'total'};
my $mergeTime = $jsondata->{'nodes'}->{$node}->{'indices'}->{'merges'}->{'total_time_in_millis'};
my $mergeTotalDocs = $jsondata->{'nodes'}->{$node}->{'indices'}->{'merges'}->{'total_docs'};
my $mergeTotalSize = $jsondata->{'nodes'}->{$node}->{'indices'}->{'merges'}->{'total_size_in_bytes'};

my $mergeDocsPerSecond;
my $mergeBytesPerSecond;
if ($mergeTime > 0) {
   $mergeDocsPerSecond =  $mergeTotalDocs/$mergeTime  ;
 }
else  { $mergeDocsPerSecond = 0; }

if ($mergeTime > 0) {
   $mergeBytesPerSecond =  $mergeTotalSize/$mergeTime  ;
 }
else  { $mergeBytesPerSecond = 0; }
push @data, "$server.$host.elasticsearch.indexstats.merges.mergeDocsPerSecond $mergeDocsPerSecond $now\n"; 
push @data, "$server.$host.elasticsearch.indexstats.merges.mergeBytesPerSecond $mergeBytesPerSecond $now\n";
push @data, "$server.$host.elasticsearch.indexstats.merges.mergeCurrent $mergeCurrent $now\n";
push @data, "$server.$host.elasticsearch.indexstats.merges.mergeCurrentDocs $mergeCurrentDocs $now\n";
push @data, "$server.$host.elasticsearch.indexstats.merges.mergeCurrentSize $mergeCurrentSize $now\n";
push @data, "$server.$host.elasticsearch.indexstats.merges.mergeTotal $mergeTotal $now\n";
push @data, "$server.$host.elasticsearch.indexstats.merges.mergeTime $mergeTime $now\n";
push @data, "$server.$host.elasticsearch.indexstats.merges.mergeTotalDocs $mergeTotalDocs $now\n";
push @data, "$server.$host.elasticsearch.indexstats.merges.mergeTotalSize $mergeTotalSize $now\n";

# segments
my $segmentsCount = $jsondata->{'nodes'}->{$node}->{'indices'}->{'segments'}->{'count'};
my $segmentsMemory = $jsondata->{'nodes'}->{$node}->{'indices'}->{'segments'}->{'memory_in_bytes'};
# translog
my $translogOps = $jsondata->{'nodes'}->{$node}->{'indices'}->{'translog'}->{'operations'};
my $translogSize = $jsondata->{'nodes'}->{$node}->{'indices'}->{'translog'}->{'size_in_bytes'};

push @data, "$server.$host.elasticsearch.indexstats.segments.segmentsCount $segmentsCount $now\n";
push @data, "$server.$host.elasticsearch.indexstats.segments.segmentsMemory $segmentsMemory $now\n";
push @data, "$server.$host.elasticsearch.indexstats.translog.translogOps $translogOps $now\n";
push @data, "$server.$host.elasticsearch.indexstats.translog.translogSize $translogSize $now\n";

# java heap and nonheap stats
my $javaHeapUsed = $jsondata->{'nodes'}->{$node}->{'jvm'}->{'mem'}->{'heap_used_in_bytes'};
my $javaHeapUsedPercent = $jsondata->{'nodes'}->{$node}->{'jvm'}->{'mem'}->{'heap_used_percent'};
my $javaHeapCommitted = $jsondata->{'nodes'}->{$node}->{'jvm'}->{'mem'}->{'heap_committed_in_bytes'};
my $javaHeapMax = $jsondata->{'nodes'}->{$node}->{'jvm'}->{'mem'}->{'heap_max_in_bytes'};
my $javaNonHeapUsed = $jsondata->{'nodes'}->{$node}->{'jvm'}->{'mem'}->{'non_heap_used_in_bytes'};
my $javaNonHeapCommitted = $jsondata->{'nodes'}->{$node}->{'jvm'}->{'mem'}->{'non_heap_used_in_bytes'};

push @data, "$server.$host.elasticsearch.indexstats.Memory.HeapMemoryUsage.javaHeapUsed $javaHeapUsed $now\n";
push @data, "$server.$host.elasticsearch.indexstats.Memory.HeapMemoryUsage.javaHeapUsedPercent $javaHeapUsedPercent $now\n";
push @data, "$server.$host.elasticsearch.indexstats.Memory.HeapMemoryUsage.javaHeapCommitted $javaHeapCommitted $now\n";
push @data, "$server.$host.elasticsearch.indexstats.Memory.HeapMemoryUsage.javaHeapMax $javaHeapMax $now\n";
push @data, "$server.$host.elasticsearch.indexstats.Memory.NonHeapMemoryUsage.javaNonHeapUsed $javaNonHeapUsed $now\n";
push @data, "$server.$host.elasticsearch.indexstats.Memory.NonHeapMemoryUsage.javaNonHeapCommitted $javaNonHeapCommitted $now\n";

# gc stats

my $gcYoungCollectionCount = $jsondata->{'nodes'}->{$node}->{'jvm'}->{'gc'}->{'collectors'}->{'young'}->{'collection_count'};
my $gcYoungCollectionTime = $jsondata->{'nodes'}->{$node}->{'jvm'}->{'gc'}->{'collectors'}->{'young'}->{'collection_time_in_millis'};
my $gcOldCollectionCount = $jsondata->{'nodes'}->{$node}->{'jvm'}->{'gc'}->{'collectors'}->{'old'}->{'collection_count'};
my $gcOldCollectionTime = $jsondata->{'nodes'}->{$node}->{'jvm'}->{'gc'}->{'collectors'}->{'old'}->{'collection_time_in_millis'};

push @data, "$server.$host.elasticsearch.indexstats.Memory.GCDuration.gcYoungCollectionCount $gcYoungCollectionCount $now\n";
push @data, "$server.$host.elasticsearch.indexstats.Memory.GCDuration.gcYoungCollectionTime $gcYoungCollectionTime $now\n";
push @data, "$server.$host.elasticsearch.indexstats.Memory.GCDuration.gcOldCollectionCount $gcOldCollectionCount $now\n";
push @data, "$server.$host.elasticsearch.indexstats.Memory.GCDuration.gcOldCollectionTime $gcOldCollectionTime $now\n";

}

