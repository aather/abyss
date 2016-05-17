#!/usr/bin/perl 

#use warnings;
#use strict;

use Fcntl qw/:flock/;

open SELF, "< $0" or die ;
flock SELF, LOCK_EX | LOCK_NB  or die "Another instance of the same program is already running: $!";

require "../../env.pl";                       # Sets up environment varilables for all agents

use Common;
use Setup;

#setpriority(0,$$,19);                          # Uncomment if running script at a lower priority

#$SIG{INT} = \&signal_handler;
#$SIG{TERM} = \&signal_handler;

my @alltests= ();
my @data = ();                                  # array to store metrics

# ---- Random read Tests
my @randreadtests = (
"fio --name=randread-nocache --ioengine=libaio --rw=randread --direct=0 --size=$filesize --numjobs=$procs --directory=/$mpt  --minimal --fadvise_hint=$fadvise --clocksource=clock_gettime ",

"fio --name=randread-partialcache --ioengine=libaio --rw=randread --direct=0 --size=$filesize --numjobs=$procs --directory=/$mpt  --minimal --fadvise_hint=$fadvise --clocksource=clock_gettime --random_distribution=$cachehit ",

"fio --name=randread-fullcache --ioengine=libaio --rw=randread --direct=0 --size=$filesize --numjobs=$procs --directory=/$mpt  --minimal --fadvise_hint=$fadvise --clocksource=clock_gettime --pre_read=1 "
);

my @randreadmmap = (
"fio --name=randreadmmap-nocache --ioengine=mmap --rw=randread --direct=0 --size=$filesize --numjobs=$procs --directory=/$mpt  --minimal --fadvise_hint=$fadvise --clocksource=clock_gettime ",

"fio --name=randreadmmap-fullcache --ioengine=mmap --rw=randread --direct=0 --size=$filesize --numjobs=$procs --directory=/$mpt  --minimal --fadvise_hint=$fadvise --clocksource=clock_gettime --pre_read=1 ",

"fio --name=randreadmmap-partialcache --ioengine=mmap --rw=randread --direct=0 --size=$filesize --numjobs=$procs --directory=/$mpt  --minimal --fadvise_hint=$fadvise --clocksource=clock_gettime --random_distribution=$cachehit "
);

 # ---- Sequential Read Tests
my @seqreadtests = (
"fio --name=seqread-nocache --ioengine=libaio --rw=read --direct=0 --size=$filesize --numjobs=$procs --directory=/$mpt --minimal --fadvise_hint=$fadvise --clocksource=clock_gettime ",

"fio --name=seqread-partialcache --ioengine=libaio --rw=read --direct=0 --size=$filesize --numjobs=$procs --directory=/$mpt  --minimal --fadvise_hint=$fadvise --clocksource=clock_gettime --random_distribution=$cachehit ",

"fio --name=seqread-fullcache --ioengine=libaio --rw=read --direct=0 --size=$filesize --numjobs=$procs --directory=/$mpt  --minimal --fadvise_hint=$fadvise --clocksource=clock_gettime --pre_read=1 "
);

my @seqreadmmap = (
"fio --name=seqreadmmap-nocache --ioengine=mmap --rw=read --direct=0 --size=$filesize --numjobs=$procs --directory=/$mpt  --minimal --fadvise_hint=$fadvise --clocksource=clock_gettime ",

"fio --name=seqreadmmap-fullcache --ioengine=mmap --rw=read --direct=0 --size=$filesize --numjobs=$procs --directory=/$mpt  --minimal --fadvise_hint=$fadvise --clocksource=clock_gettime --pre_read=1 ",

"fio --name=seqreadmmap-partialcache --ioengine=mmap --rw=read --direct=0 --size=$filesize --numjobs=$procs --directory=/$mpt  --minimal --fadvise_hint=$fadvise --clocksource=clock_gettime --random_distribution=$cachehit "
); 

 # ---- Random Write Tests
my @randwritetests = (
"fio --name=randwrite-nocache --ioengine=libaio --rw=randwrite --direct=0 --size=$filesize --numjobs=$procs --directory=/$mpt  --minimal --fadvise_hint=$fadvise --end_fsync=$end_fsync --clocksource=clock_gettime ",

"fio --name=randwrite-fullcache --ioengine=libaio --rw=randwrite --direct=0 --size=$filesize --numjobs=$procs --directory=/$mpt  --minimal --fadvise_hint=$fadvise --clocksource=clock_gettime --pre_read=1 ",

"fio --name=randwrite-fsync --fsync=32 --ioengine=libaio --rw=randwrite --direct=0 --size=$filesize --numjobs=$procs --directory=/$mpt --minimal --fadvise_hint=$fadvise --clocksource=clock_gettime ",

"fio --name=randwrite-Synchronous --sync=1 --ioengine=libaio --rw=randwrite --direct=0 --size=$filesize --numjobs=$procs --directory=/$mpt --minimal --fadvise_hint=$fadvise --clocksource=clock_gettime "
);

my @randwritemmap = (

"fio --name=randwritemmap-nocache --ioengine=mmap --rw=randwrite --direct=0 --size=$filesize --numjobs=$procs --directory=/$mpt  --minimal --fadvise_hint=$fadvise --end_fsync=$end_fsync --clocksource=clock_gettime ",

"fio --name=randwritemmap-fullcache --ioengine=mmap --rw=randwrite --direct=0 --size=$filesize --numjobs=$procs --directory=/$mpt  --minimal --fadvise_hint=$fadvise --clocksource=clock_gettime --pre_read=1 "
);

 # ---- Sequential Write Tests
my @seqwritetests = (
"fio --name=seqwrite-nocache --ioengine=libaio --rw=write --direct=0 --size=$filesize --numjobs=$procs --directory=/$mpt  --minimal --fadvise_hint=$fadvise --end_fsync=$end_fsync --clocksource=clock_gettime ",

"fio --name=seqwrite-fullcache --ioengine=libaio --rw=write --direct=0 --size=$filesize --numjobs=$procs --directory=/$mpt  --minimal --fadvise_hint=$fadvise --clocksource=clock_gettime --pre_read=1 ",

"fio --name=seqwrite-fsync --fsync=32 --ioengine=libaio --rw=write --direct=0 --size=$filesize --numjobs=$procs --directory=/$mpt --minimal --fadvise_hint=$fadvise --clocksource=clock_gettime ",

"fio --name=seqwrite-Synchronous --sync=1 --ioengine=libaio --rw=write --direct=0 --size=$filesize --numjobs=$procs --directory=/$mpt --minimal --fadvise_hint=$fadvise --clocksource=clock_gettime "
);

my @seqwritemmap = (
"fio --name=seqwritemmap-nocache --ioengine=mmap --rw=write --direct=0 --size=$filesize --numjobs=$procs --directory=/$mpt  --minimal --fadvise_hint=$fadvise --end_fsync=$end_fsync --clocksource=clock_gettime ",

"fio --name=seqwritemmap-fullcache --ioengine=mmap --rw=write --direct=0 --size=$filesize --numjobs=$procs --directory=/$mpt  --minimal --fadvise_hint=$fadvise --clocksource=clock_gettime --pre_read=1 "
);

 # ---- Random  Mixed Tests
my @randmixedtests = (
"fio --name=randmixed-nocache --ioengine=libaio --rw=randrw --direct=0 --size=$filesize --numjobs=$procs --directory=/$mpt  --minimal --fadvise_hint=$fadvise --end_fsync=$end_fsync --clocksource=clock_gettime --rwmixread=$percentread --rwmixwrite=$percentwrite ",

"fio --name=randmixed-partialcache --ioengine=libaio --rw=randrw --direct=0 --size=$filesize --numjobs=$procs --directory=/$mpt  --minimal --fadvise_hint=$fadvise --clocksource=clock_gettime --rwmixread=$percentread --rwmixwrite=$percentwrite --random_distribution=$cachehit ",

"fio --name=randmixed-fullcache --ioengine=libaio --rw=randrw --direct=0 --size=$filesize --numjobs=$procs --directory=/$mpt  --minimal --fadvise_hint=$fadvise --clocksource=clock_gettime --rwmixread=$percentread --rwmixwrite=$percentwrite --pre_read=1 "
);

my @randmixedmmap = (
"fio --name=randmixedmmap-nocache --ioengine=mmap --rw=randrw --direct=0 --size=$filesize --numjobs=$procs --directory=/$mpt  --minimal --fadvise_hint=$fadvise --end_fsync=$end_fsync --clocksource=clock_gettime --rwmixread=$percentread --rwmixwrite=$percentwrite ",

"fio --name=randmixedmmap-fullcache --ioengine=mmap --rw=randrw --direct=0 --size=$filesize --numjobs=$procs --directory=/$mpt  --minimal --fadvise_hint=$fadvise --clocksource=clock_gettime --rwmixread=$percentread --rwmixwrite=$percentwrite --pre_read=1 ",

"fio --name=randmixedmmap-partialcache --ioengine=mmap --rw=randrw --direct=0 --size=$filesize --numjobs=$procs --directory=/$mpt  --minimal --fadvise_hint=$fadvise --clocksource=clock_gettime --rwmixread=$percentread --rwmixwrite=$percentwrite --random_distribution=$cachehit "
);

 # ---- Sequential Mixed Tests
my @seqmixedtests = (
"fio --name=seqmixed-nocache --ioengine=libaio --rw=rw --direct=0 --size=$filesize --numjobs=$procs --directory=/$mpt  --minimal --fadvise_hint=$fadvise --end_fsync=$end_fsync --clocksource=clock_gettime --rwmixread=$percentread --rwmixwrite=$percentwrite ",

"fio --name=seqmixed-partialcache --ioengine=libaio --rw=rw --direct=0 --size=$filesize --numjobs=$procs --directory=/$mpt  --minimal --fadvise_hint=$fadvise --clocksource=clock_gettime --rwmixread=$percentread --rwmixwrite=$percentwrite --random_distribution=$cachehit ",

"fio --name=seqmixed-fullcache --ioengine=libaio --rw=rw --direct=0 --size=$filesize --numjobs=$procs --directory=/$mpt  --minimal --fadvise_hint=$fadvise --clocksource=clock_gettime --rwmixread=$percentread --rwmixwrite=$percentwrite --pre_read=1 "
);

my @seqmixedmmap = (

"fio --name=seqmixedmmap-nocache --ioengine=mmap --rw=rw --direct=0 --size=$filesize --numjobs=$procs --directory=/$mpt  --minimal --fadvise_hint=$fadvise --end_fsync=$end_fsync --clocksource=clock_gettime --rwmixread=$percentread --rwmixwrite=$percentwrite ",

"fio --name=seqmixedmmap-fullcache --ioengine=mmap --rw=rw --direct=0 --size=$filesize --numjobs=$procs --directory=/$mpt  --minimal --fadvise_hint=$fadvise --clocksource=clock_gettime --rwmixread=$percentread --rwmixwrite=$percentwrite --pre_read=1 ",

"fio --name=seqmixedmmap-partialcache --ioengine=mmap --rw=rw --direct=0 --size=$filesize --numjobs=$procs --directory=/$mpt  --minimal --fadvise_hint=$fadvise --clocksource=clock_gettime --rwmixread=$percentread --rwmixwrite=$percentwrite --random_distribution=$cachehit "
);

 # ---- IO Latency Tests
my @iolatencytests = (
"fio --name=read-latency --ioengine=libaio --rw=randread --direct=1 --size=$filesize --directory=/$mpt --iodepth=1 --minimal --fadvise_hint=$fadvise --clocksource=clock_gettime ",
"fio --name=write-latency --ioengine=libaio --rw=randwrite --direct=1 --size=$filesize --directory=/$mpt --iodepth=1 --minimal --fadvise_hint=$fadvise --clocksource=clock_gettime "
);

 # ---- direct IO  Tests
my @iodirecttests = (
"fio --name=read-direct --ioengine=libaio --rw=randread --direct=1 --size=$filesize --directory=/$mpt --iodepth=$iodepth --minimal --fadvise_hint=$fadvise --clocksource=clock_gettime ",
"fio --name=write-direct --ioengine=libaio --rw=randwrite --direct=1 --size=$filesize --directory=/$mpt --iodepth=$iodepth --minimal --fadvise_hint=$fadvise --clocksource=clock_gettime "
);
if ($iolatencytests ==1) { push (@alltests, @iolatencytests);}
if ($iodirecttests ==1) { push (@alltests, @iodirecttests);}
if ($randreadtests == 1 ) { push (@alltests, @randreadtests); }
if ($seqreadtests == 1)  { push (@alltests, @seqreadtests);  }
if ($randwritetests == 1) { push (@alltests, @randwritetests);}
if ($seqwritetests == 1)  { push (@alltests, @seqwritetests); }
if ($randmixedtests == 1)  { push (@alltests, @randmixedtests);}
if ($seqmixedtests == 1)  { push (@alltests, @seqmixedtests); }
if ($randreadmmap == 1)  { push (@alltests, @randreadmmap); }
if ($seqreadmmap == 1)  { push (@alltests, @seqreadmmap); }
if ($randwritemmap == 1)  { push (@alltests, @randwritemmap); }
if ($seqwritemmap == 1)  { push (@alltests, @seqwritemmap); }
if ($randmixedmmap == 1)  { push (@alltests, @randmixedmmap); }
if ($seqmixedmmap == 1)  { push (@alltests, @seqmixedmmap); }

open(GRAPHITE, "| ../../common/nc -w 1000 $carbon_server $carbon_port") || die "failed to send: $!\n";


# ------------------------------agent specific sub routines-------------------
my @stats;
my @rtot;
my @rbw;
my @riops;
my @busy;
my @wtot;
my @wbw;
my @wiops;
my @rlatency;
my @wlatency;
my $testfiles;
my $loops=$iterations;
my $same;
my $start = `date +%s`;
foreach $filesystem (@filesystems){  # Run tests against all filesystem requested
  print "filesystem selected: $filesystem \n";
  print "mount point selected:  $mpt \n";
  print "Devices selected: @devices \n\n";
  print "Setting up filesystem: $filesystem\n";
  setup_filesystem($filesystem,$mpt,\@devices);
  my $output =`df -T`;
  print "Please check if output matches your request:\n $output\n";
  $same = $start;   

  my @args = ("./sysio.pl", "$same", "$filesystem");
    if (my $pid = fork) {
      #  waitpid($pid);  
    }
    else {
      exec(@args);
  }
  my @args = ("./iolatency.pl", "$same", "$filesystem");
    if (my $pid = fork) {
      #  waitpid($pid);  
    }
    else {
      exec(@args);
  }
  foreach my $test (@alltests){  # Running tests one by one
      my @list = split / /, $test;
      my @word = split /=/,$list[1];
      # zfs does not support direct IO
      next if ((($word[1] =~ /latency/) || ($word[1] =~ /direct/))  && ($filesystem =~ /zfs/)) ; 
      foreach my $size (@blocks){
        my $temp = $test."--bs=$size |";
        print "Block Size: $size | Test: $temp\n";
        if ($filesystem =~ /zfs/){
           `sudo zfs set recordsize=$size pool`;	
	   print "ZFS: Setting recordsize=$size\n";
        }
        while ($loops-- > 0 ){ # perform each test with various block sizes for that many $iterations
          open (FIO, $temp) || die print "failed to get data: $!\n";
          while (<FIO>) {
             @stats= split(/;/);
          }
          close(FIO);
          if (($stats[2] =~ /latency/) || ($stats[2] =~ /direct/)){
              @data = populate_data($server,$host,$size,$same,$filesystem,1,$stats[2],$stats[5],$stats[6],$stats[7],$stats[46],$stats[47],$stats[48],$stats[38], $stats[79], $stats[121]);
	  }
          else {
             @data = populate_data($server,$host,$size,$same,$filesystem,$procs,$stats[2],$stats[5],$stats[6],$stats[7],$stats[46],$stats[47],$stats[48],$stats[38], $stats[79], $stats[121]);
          }

          print @data;                            # For Testing only 
          print "\n------\n";                     # For Testing only
          print GRAPHITE  @data;                  # Ship metrics to carbon server

          @data=();                               # Initialize for next set of metrics
 	  @stats=();
          $same = $same + 5;

	  # Need to release memory from ZFS ARC after every test run. 
          if ($filesystem =~ /zfs/) { 
           my $output =`cat /proc/spl/kstat/zfs/arcstats|grep ^size`;
           print "ZFS ARC Size Before:$output\n";
          `sudo zpool export pool`;
          `sudo zpool import pool`;
           my $output =`cat /proc/spl/kstat/zfs/arcstats|grep ^size`;
           print "ZFS ARC Size After: $output\n";
          }
        }
    $loops=$iterations;
    $same=$start;    # Reset it to show all tests in the same time window. Makes it convenient to see in graph
   } 
  print "Completed -- Block: @blocks | Tests: $test\n";
  print "Removing test files: /$mpt/$word[1]\n";
  `sudo rm /$mpt/$word[1]*`;
  #`pkill -9 sysio.pl`; `pkill -9 syslat.pl`;
  #`pkill -9 sysio.pl`; `pkill -9 syslat.pl`;
  $same=$start;			# Reset it to show all filesystem tests in one time window 
  sleep 5;
  }
  #`pkill -9 sysio.pl`; `pkill -9 iolatency.pl`;
  # Run all tests for the next file system requested
 }
print "Completed: All Tests\n @alltests\n";
close (GRAPHITE);
