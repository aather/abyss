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

#open(GRAPHITE, "| ../../common/nc -w 50 $carbon_server $carbon_port") || die "failed to send: $!\n";
open(GRAPHITE, "| ../../common/ncat -i 1000000ms $carbon_server $carbon_port") || die "failed to send: $!\n";

# ------------------------------agent specific sub routines-------------------
sub build_HashArray;
sub collect_HeapGCStats;
sub collect_ThreadStats;
sub collect_ReqStats;

my %hash;
my %pchash;
my %jvmhash;
my %cmshash;
my %gpgchash;
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
my @GPGC = ('"GPGC New"', '"GPGC Old"');
my @GCStats = ('CollectionCount', 'CollectionTime');
my @ThreadPool = ('ajp-bio-0.0.0.0-8009','http-nio-0.0.0.0-7101', 'http-0.0.0.0-7001');
my @ThreadStats = ('currentThreadCount', 'currentThreadsBusy', 'maxThreads', 'connectionCount');
my @requestStats = ('requestCount', 'errorCount', 'processingTime', 'bytesReceived', 'bytesSent');

my $token = `jps|grep Bootstrap`;
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
#$GC= `/bin/ps -p $pid[0] -o command |grep CMS`;
    %cmshash = build_HashArray(\@CMS, \@GCStats);
    %parhash = build_HashArray(\@Par, \@GCStats);
    %g1hash = build_HashArray(\@G1, \@GCStats);
    %gpgchash = build_HashArray(\@GPGC, \@GCStats);

    %thrhash = build_HashArray(\@ThreadPool, \@ThreadStats);
    %reqhash = build_HashArray(\@ThreadPool, \@requestStats);

while (1) {

 $now = `date +%s`;

 collect_HeapGCStats;
 collect_ThreadStats;
 collect_ReqStats;

 #print @data; 					# For Testing only 
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

sub collect_HeapGCStats {
 my $results = 0;

 foreach my $key (keys %jvmhash) {
   foreach (@{$jvmhash{$key}}) {
   $results =  `wget -q -O - http://127.0.0.1:8778/jolokia/read/java.lang:type=Memory/$key/$_`;
   if ($results !~ /NotFoundException/) {
   $results =~/"value":(\d+)/;
   push @data, "$server.$host.tomcat.Memory.$key.$_ $1 $now\n";
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
   push @data, "$server.$host.tomcat.Memory.GCDuration.PGC.$pgkey.$parhash{$key}[0] $1 $now\n";

   $results =  `wget -q -O - http://127.0.0.1:8778/jolokia/read/java.lang:type=GarbageCollector,name=$key/$parhash{$key}[1]`;
   $results =~/"value":(\d+)/;
   push @data, "$server.$host.tomcat.Memory.GCDuration.PGC.$pgkey.$parhash{$key}[1] $1 $now\n";
   }
  }

 foreach my $key (keys %cmshash) { # cms 
   my $pgkey = $key;
      $pgkey =~ s/"//g;
      $pgkey =~ s/ /-/g;

   $results =  `wget -q -O - http://127.0.0.1:8778/jolokia/read/java.lang:type=GarbageCollector,name=$key/$cmshash{$key}[0]`;
   if ($results !~ /NotFoundException/) { 
   $results =~/"value":(\d+)/;
   push @data, "$server.$host.tomcat.Memory.GCDuration.CMS.$pgkey.$cmshash{$key}[0] $1 $now\n";

   $results =  `wget -q -O - http://127.0.0.1:8778/jolokia/read/java.lang:type=GarbageCollector,name=$key/$cmshash{$key}[1]`;
   $results =~/"value":(\d+)/;
   push @data, "$server.$host.tomcat.Memory.GCDuration.CMS.$pgkey.$cmshash{$key}[1] $1 $now\n";
   }
  }

 foreach my $key (keys %g1hash) { # G1 
   my $pgkey = $key;
      $pgkey =~ s/"//g;
      $pgkey =~ s/ /-/g;

   $results =  `wget -q -O - http://127.0.0.1:8778/jolokia/read/java.lang:type=GarbageCollector,name=$key/$g1hash{$key}[0]`;
   if ($results !~ /NotFoundException/) {
   $results =~/"value":(\d+)/;
   push @data, "$server.$host.tomcat.Memory.GCDuration.G1.$pgkey.$g1hash{$key}[0] $1 $now\n";

   $results =  `wget -q -O - http://127.0.0.1:8778/jolokia/read/java.lang:type=GarbageCollector,name=$key/$g1hash{$key}[1]`;
   $results =~/"value":(\d+)/;
   push @data, "$server.$host.tomcat.Memory.GCDuration.G1.$pgkey.$g1hash{$key}[1] $1 $now\n";
   }
  }

 foreach my $key (keys %gpgchash) { # GPGC Zinc Garbage Collector 
   my $pgkey = $key;
      $pgkey =~ s/"//g;
      $pgkey =~ s/ /-/g;

   $results =  `wget -q -O - http://127.0.0.1:8778/jolokia/read/java.lang:type=GarbageCollector,name=$key/$gpgchash{$key}[0]`;
   if ($results !~ /NotFoundException/) {
   $results =~/"value":(\d+)/;
   push @data, "$server.$host.tomcat.Memory.GCDuration.GPGC.$pgkey.$gpgchash{$key}[0] $1 $now\n";

   $results =  `wget -q -O - http://127.0.0.1:8778/jolokia/read/java.lang:type=GarbageCollector,name=$key/$gpgchash{$key}[1]`;
   $results =~/"value":(\d+)/;
   push @data, "$server.$host.tomcat.Memory.GCDuration.GPGC.$pgkey.$gpgchash{$key}[1] $1 $now\n";
   }
  }
}

sub collect_ThreadStats {
 my $results = 0;
 foreach my $key (keys %thrhash) { 
 my $pgkey = $key;
      #$pgkey =~ s/"//g;
      #$pgkey =~ s/ /-/g;
      $pgkey =~ s/-0.0.0.0//g;

   if ($key !~ /http-0.0.0.0-7001/){ # ajp and nio only
    $results =  `wget -q -O - http://127.0.0.1:8778/jolokia/read/Catalina:type=ThreadPool,name=\\"$key\\"/$thrhash{$key}[0]`;
    if ($results !~ /NotFoundException/) {
     $results =~/"value":(\d+)/;
     push @data, "$server.$host.tomcat.ThreadPool.$pgkey.$thrhash{$key}[0] $1 $now\n";
     }

     $results =  `wget -q -O - http://127.0.0.1:8778/jolokia/read/Catalina:type=ThreadPool,name=\\"$key\\"/$thrhash{$key}[1]`;
    if ($results !~ /NotFoundException/) {
     $results =~/"value":(\d+)/;
     push @data, "$server.$host.tomcat.ThreadPool.$pgkey.$thrhash{$key}[1] $1 $now\n";
     }

     $results =  `wget -q -O - http://127.0.0.1:8778/jolokia/read/Catalina:type=ThreadPool,name=\\"$key\\"/$thrhash{$key}[2]`;
    if ($results !~ /NotFoundException/) {
     $results =~/"value":(\d+)/;
     push @data, "$server.$host.tomcat.ThreadPool.$pgkey.$thrhash{$key}[2] $1 $now\n";
     }

     $results =  `wget -q -O - http://127.0.0.1:8778/jolokia/read/Catalina:type=ThreadPool,name=\\"$key\\"/$thrhash{$key}[3]`;
    if ($results !~ /NotFoundException/) {
     $results =~/"value":(\d+)/;
     push @data, "$server.$host.tomcat.ThreadPool.$pgkey.$thrhash{$key}[3] $1 $now\n";
    }
   }
 else {    #  http only. It misinterpret escape characters
    $results =  `wget -q -O - http://127.0.0.1:8778/jolokia/read/Catalina:type=ThreadPool,name="$key"/$thrhash{$key}[0]`;
    if ($results !~ /NotFoundException/) {
    $results =~/"value":(\d+)/;
     push @data, "$server.$host.tomcat.ThreadPool.$pgkey.$thrhash{$key}[0] $1 $now\n";
     }

    $results =  `wget -q -O - http://127.0.0.1:8778/jolokia/read/Catalina:type=ThreadPool,name="$key"/$thrhash{$key}[1]`;
    if ($results !~ /NotFoundException/) {
     $results =~/"value":(\d+)/;
     push @data, "$server.$host.tomcat.ThreadPool.$pgkey.$thrhash{$key}[1] $1 $now\n";
     }

     $results =  `wget -q -O - http://127.0.0.1:8778/jolokia/read/Catalina:type=ThreadPool,name="$key"/$thrhash{$key}[2]`;
     if ($results !~ /NotFoundException/) {
     $results =~/"value":(\d+)/;
     push @data, "$server.$host.tomcat.ThreadPool.$pgkey.$thrhash{$key}[2] $1 $now\n";
     }

     $results =  `wget -q -O - http://127.0.0.1:8778/jolokia/read/Catalina:type=ThreadPool,name="$key"/$thrhash{$key}[3]`;
     if ($results !~ /NotFoundException/) {
     $results =~/"value":(\d+)/;
     push @data, "$server.$host.tomcat.ThreadPool.$pgkey.$thrhash{$key}[3] $1 $now\n";
     }
   }
 }
}
sub collect_ReqStats {
  my $results = 0;
  foreach my $key (keys %reqhash) {
  my $pgkey = $key;
      #$pgkey =~ s/"//g;
      #$pgkey =~ s/ /-/g;
      $pgkey =~ s/-0.0.0.0//g;

   if ($key !~ /http-0.0.0.0-7001/){ # ajp and nio only
    $results =  `wget -q -O - http://127.0.0.1:8778/jolokia/read/Catalina:type=GlobalRequestProcessor,name=\\"$key\\"/$reqhash{$key}[0]`;
    if ($results !~ /NotFoundException/) {
     $results =~/"value":(\d+)/;
     push @data, "$server.$host.tomcat.GlobalRequestProcessor.$pgkey.$reqhash{$key}[0] $1 $now\n";
     }
     $results =  `wget -q -O - http://127.0.0.1:8778/jolokia/read/Catalina:type=GlobalRequestProcessor,name=\\"$key\\"/$reqhash{$key}[1]`;
    if ($results !~ /NotFoundException/) {
     $results =~/"value":(\d+)/;
     push @data, "$server.$host.tomcat.GlobalRequestProcessor.$pgkey.$reqhash{$key}[1] $1 $now\n";
     }

     $results =  `wget -q -O - http://127.0.0.1:8778/jolokia/read/Catalina:type=GlobalRequestProcessor,name=\\"$key\\"/$reqhash{$key}[2]`;
    if ($results !~ /NotFoundException/) {
     $results =~/"value":(\d+)/;
     push @data, "$server.$host.tomcat.GlobalRequestProcessor.$pgkey.$reqhash{$key}[2] $1 $now\n";
     }

     $results =  `wget -q -O - http://127.0.0.1:8778/jolokia/read/Catalina:type=GlobalRequestProcessor,name=\\"$key\\"/$reqhash{$key}[3]`;
    if ($results !~ /NotFoundException/) {
     $results =~/"value":(\d+)/;
     push @data, "$server.$host.tomcat.GlobalRequestProcessor.$pgkey.$reqhash{$key}[3] $1 $now\n";
    }
     $results =  `wget -q -O - http://127.0.0.1:8778/jolokia/read/Catalina:type=GlobalRequestProcessor,name=\\"$key\\"/$reqhash{$key}[4]`;
    if ($results !~ /NotFoundException/) {
     $results =~/"value":(\d+)/;
     push @data, "$server.$host.tomcat.GlobalRequestProcessor.$pgkey.$reqhash{$key}[4] $1 $now\n";
    }
   }
 else {    #  http only. It misinterpret escape characters
    $results =  `wget -q -O - http://127.0.0.1:8778/jolokia/read/Catalina:type=GlobalRequestProcessor,name="$key"/$reqhash{$key}[0]`;
    if ($results !~ /NotFoundException/) {
    $results =~/"value":(\d+)/;
     push @data, "$server.$host.tomcat.GlobalRequestProcessor.$pgkey.$reqhash{$key}[0] $1 $now\n";
     }

    $results =  `wget -q -O - http://127.0.0.1:8778/jolokia/read/Catalina:type=GlobalRequestProcessor,name="$key"/$reqhash{$key}[1]`;
    if ($results !~ /NotFoundException/) {
     $results =~/"value":(\d+)/;
     push @data, "$server.$host.tomcat.GlobalRequestProcessor.$pgkey.$reqhash{$key}[1] $1 $now\n";
     }

     $results =  `wget -q -O - http://127.0.0.1:8778/jolokia/read/Catalina:type=GlobalRequestProcessor,name="$key"/$reqhash{$key}[2]`;
     if ($results !~ /NotFoundException/) {
     $results =~/"value":(\d+)/;
     push @data, "$server.$host.tomcat.GlobalRequestProcessor.$pgkey.$reqhash{$key}[2] $1 $now\n";
     }

     $results =  `wget -q -O - http://127.0.0.1:8778/jolokia/read/Catalina:type=GlobalRequestProcessor,name="$key"/$reqhash{$key}[3]`;
     if ($results !~ /NotFoundException/) {
     $results =~/"value":(\d+)/;
     push @data, "$server.$host.tomcat.GlobalRequestProcessor.$pgkey.$reqhash{$key}[3] $1 $now\n";
     }

     $results =  `wget -q -O - http://127.0.0.1:8778/jolokia/read/Catalina:type=GlobalRequestProcessor,name="$key"/$reqhash{$key}[4]`;
     if ($results !~ /NotFoundException/) {
     $results =~/"value":(\d+)/;
     push @data, "$server.$host.tomcat.GlobalRequestProcessor.$pgkey.$reqhash{$key}[4] $1 $now\n";
     }
   }
 }
}

