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
"fio --name=randread-nocache1 --ioengine=libaio --rw=randread --direct=0 --size=$filesize --numjobs=$procs --directory=/$mpt  --minimal --fadvise_hint=$fadvise --clocksource=clock_gettime ",

"fio --name=randread-partialcache1 --ioengine=libaio --rw=randread --direct=0 --size=$filesize --numjobs=$procs --directory=/$mpt  --minimal --fadvise_hint=$fadvise --clocksource=clock_gettime --random_distribution=$cachehit ",

"fio --name=randread-fullcache1 --ioengine=libaio --rw=randread --direct=0 --size=$filesize --numjobs=$procs --directory=/$mpt  --minimal --fadvise_hint=$fadvise --clocksource=clock_gettime --pre_read=1 "
);

my @randreadmmap = (
"fio --name=randreadmmap-nocache1 --ioengine=mmap --rw=randread --direct=0 --size=$filesize --numjobs=$procs --directory=/$mpt  --minimal --fadvise_hint=$fadvise --clocksource=clock_gettime ",

"fio --name=randreadmmap-fullcache1 --ioengine=mmap --rw=randread --direct=0 --size=$filesize --numjobs=$procs --directory=/$mpt  --minimal --fadvise_hint=$fadvise --clocksource=clock_gettime --pre_read=1 ",

"fio --name=randreadmmap-partialcache1 --ioengine=mmap --rw=randread --direct=0 --size=$filesize --numjobs=$procs --directory=/$mpt  --minimal --fadvise_hint=$fadvise --clocksource=clock_gettime --random_distribution=$cachehit "
);

 # ---- Sequential Read Tests
my @seqreadtests = (
"fio --name=seqread-nocache1 --ioengine=libaio --rw=read --direct=0 --size=$filesize --numjobs=$procs --directory=/$mpt --minimal --fadvise_hint=$fadvise --clocksource=clock_gettime ",

"fio --name=seqread-partialcache1 --ioengine=libaio --rw=read --direct=0 --size=$filesize --numjobs=$procs --directory=/$mpt  --minimal --fadvise_hint=$fadvise --clocksource=clock_gettime --random_distribution=$cachehit ",

"fio --name=seqread-fullcache1 --ioengine=libaio --rw=read --direct=0 --size=$filesize --numjobs=$procs --directory=/$mpt  --minimal --fadvise_hint=$fadvise --clocksource=clock_gettime --pre_read=1 "
);

my @seqreadmmap = (
"fio --name=seqreadmmap-nocache1 --ioengine=mmap --rw=read --direct=0 --size=$filesize --numjobs=$procs --directory=/$mpt  --minimal --fadvise_hint=$fadvise --clocksource=clock_gettime ",

"fio --name=seqreadmmap-fullcache1 --ioengine=mmap --rw=read --direct=0 --size=$filesize --numjobs=$procs --directory=/$mpt  --minimal --fadvise_hint=$fadvise --clocksource=clock_gettime --pre_read=1 ",

"fio --name=seqreadmmap-partialcache1 --ioengine=mmap --rw=read --direct=0 --size=$filesize --numjobs=$procs --directory=/$mpt  --minimal --fadvise_hint=$fadvise --clocksource=clock_gettime --random_distribution=$cachehit "
); 

 # ---- Random Write Tests
my @randwritetests = (
"fio --name=randwrite-nocache1 --ioengine=libaio --rw=randwrite --direct=0 --size=$filesize --numjobs=$procs --directory=/$mpt  --minimal --fadvise_hint=$fadvise --end_fsync=$end_fsync --clocksource=clock_gettime ",

"fio --name=randwrite-fullcache1 --ioengine=libaio --rw=randwrite --direct=0 --size=$filesize --numjobs=$procs --directory=/$mpt  --minimal --fadvise_hint=$fadvise --clocksource=clock_gettime --pre_read=1 ",

"fio --name=randwrite-partialcache1 --ioengine=libaio --rw=randwrite --direct=0 --size=$filesize --numjobs=$procs --directory=/$mpt  --minimal --fadvise_hint=$fadvise --clocksource=clock_gettime --random_distribution=$cachehit ",

"fio --name=randwrite-fsync1 --fsync=32 --ioengine=libaio --rw=randwrite --direct=0 --size=$filesize --numjobs=$procs --directory=/$mpt --minimal --fadvise_hint=$fadvise --clocksource=clock_gettime ",

"fio --name=randwrite-Synchronous1 --sync=1 --ioengine=libaio --rw=randwrite --direct=0 --size=$filesize --numjobs=$procs --directory=/$mpt --minimal --fadvise_hint=$fadvise --clocksource=clock_gettime "
);

my @randwritemmap = (

"fio --name=randwritemmap-nocache1 --ioengine=mmap --rw=randwrite --direct=0 --size=$filesize --numjobs=$procs --directory=/$mpt  --minimal --fadvise_hint=$fadvise --end_fsync=$end_fsync --clocksource=clock_gettime ",

"fio --name=randwritemmap-partialcache1 --ioengine=mmap --rw=randwrite --direct=0 --size=$filesize --numjobs=$procs --directory=/$mpt  --minimal --fadvise_hint=$fadvise --clocksource=clock_gettime --random_distribution=$cachehit ",

"fio --name=randwritemmap-fullcache1 --ioengine=mmap --rw=randwrite --direct=0 --size=$filesize --numjobs=$procs --directory=/$mpt  --minimal --fadvise_hint=$fadvise --clocksource=clock_gettime --pre_read=1 "
);

 # ---- Sequential Write Tests
my @seqwritetests = (
"fio --name=seqwrite-nocache1 --ioengine=libaio --rw=write --direct=0 --size=$filesize --numjobs=$procs --directory=/$mpt  --minimal --fadvise_hint=$fadvise --end_fsync=$end_fsync --clocksource=clock_gettime ",

"fio --name=seqwrite-fullcache1 --ioengine=libaio --rw=write --direct=0 --size=$filesize --numjobs=$procs --directory=/$mpt  --minimal --fadvise_hint=$fadvise --clocksource=clock_gettime --pre_read=1 ",

"fio --name=seqwrite-partialcache1 --ioengine=libaio --rw=write --direct=0 --size=$filesize --numjobs=$procs --directory=/$mpt  --minimal --fadvise_hint=$fadvise --clocksource=clock_gettime --random_distribution=$cachehit ",

"fio --name=seqwrite-fsync1 --fsync=32 --ioengine=libaio --rw=write --direct=0 --size=$filesize --numjobs=$procs --directory=/$mpt --minimal --fadvise_hint=$fadvise --clocksource=clock_gettime ",

"fio --name=seqwrite-Synchronous1 --sync=1 --ioengine=libaio --rw=write --direct=0 --size=$filesize --numjobs=$procs --directory=/$mpt --minimal --fadvise_hint=$fadvise --clocksource=clock_gettime "
);

my @seqwritemmap = (
"fio --name=seqwritemmap-nocache1 --ioengine=mmap --rw=write --direct=0 --size=$filesize --numjobs=$procs --directory=/$mpt  --minimal --fadvise_hint=$fadvise --end_fsync=$end_fsync --clocksource=clock_gettime ",

"fio --name=seqwritemmap-partialcache1 --ioengine=mmap --rw=write --direct=0 --size=$filesize --numjobs=$procs --directory=/$mpt  --minimal --fadvise_hint=$fadvise --clocksource=clock_gettime --random_distribution=$cachehit ",

"fio --name=seqwritemmap-fullcache1 --ioengine=mmap --rw=write --direct=0 --size=$filesize --numjobs=$procs --directory=/$mpt  --minimal --fadvise_hint=$fadvise --clocksource=clock_gettime --pre_read=1 "
);

 # ---- Random  Mixed Tests
my @randmixedtests = (
"fio --name=randmixed-nocache1 --ioengine=libaio --rw=randrw --direct=0 --size=$filesize --numjobs=$procs --directory=/$mpt  --minimal --fadvise_hint=$fadvise --end_fsync=$end_fsync --clocksource=clock_gettime --rwmixread=$percentread --rwmixwrite=$percentwrite ",

"fio --name=randmixed-partialcache1 --ioengine=libaio --rw=randrw --direct=0 --size=$filesize --numjobs=$procs --directory=/$mpt  --minimal --fadvise_hint=$fadvise --clocksource=clock_gettime --rwmixread=$percentread --rwmixwrite=$percentwrite --random_distribution=$cachehit ",

"fio --name=randmixed-fullcache1 --ioengine=libaio --rw=randrw --direct=0 --size=$filesize --numjobs=$procs --directory=/$mpt  --minimal --fadvise_hint=$fadvise --clocksource=clock_gettime --rwmixread=$percentread --rwmixwrite=$percentwrite --pre_read=1 "
);

my @randmixedmmap = (
"fio --name=randmixedmmap-nocache1 --ioengine=mmap --rw=randrw --direct=0 --size=$filesize --numjobs=$procs --directory=/$mpt  --minimal --fadvise_hint=$fadvise --end_fsync=$end_fsync --clocksource=clock_gettime --rwmixread=$percentread --rwmixwrite=$percentwrite ",

"fio --name=randmixedmmap-fullcache1 --ioengine=mmap --rw=randrw --direct=0 --size=$filesize --numjobs=$procs --directory=/$mpt  --minimal --fadvise_hint=$fadvise --clocksource=clock_gettime --rwmixread=$percentread --rwmixwrite=$percentwrite --pre_read=1 ",

"fio --name=randmixedmmap-partialcache1 --ioengine=mmap --rw=randrw --direct=0 --size=$filesize --numjobs=$procs --directory=/$mpt  --minimal --fadvise_hint=$fadvise --clocksource=clock_gettime --rwmixread=$percentread --rwmixwrite=$percentwrite --random_distribution=$cachehit "
);

 # ---- Sequential Mixed Tests
my @seqmixedtests = (
"fio --name=seqmixed-nocache1 --ioengine=libaio --rw=rw --direct=0 --size=$filesize --numjobs=$procs --directory=/$mpt  --minimal --fadvise_hint=$fadvise --end_fsync=$end_fsync --clocksource=clock_gettime --rwmixread=$percentread --rwmixwrite=$percentwrite ",

"fio --name=seqmixed-partialcache1 --ioengine=libaio --rw=rw --direct=0 --size=$filesize --numjobs=$procs --directory=/$mpt  --minimal --fadvise_hint=$fadvise --clocksource=clock_gettime --rwmixread=$percentread --rwmixwrite=$percentwrite --random_distribution=$cachehit ",

"fio --name=seqmixed-fullcache1 --ioengine=libaio --rw=rw --direct=0 --size=$filesize --numjobs=$procs --directory=/$mpt  --minimal --fadvise_hint=$fadvise --clocksource=clock_gettime --rwmixread=$percentread --rwmixwrite=$percentwrite --pre_read=1 "
);

my @seqmixedmmap = (

"fio --name=seqmixedmmap-nocache1 --ioengine=mmap --rw=rw --direct=0 --size=$filesize --numjobs=$procs --directory=/$mpt  --minimal --fadvise_hint=$fadvise --end_fsync=$end_fsync --clocksource=clock_gettime --rwmixread=$percentread --rwmixwrite=$percentwrite ",

"fio --name=seqmixedmmap-fullcache1 --ioengine=mmap --rw=rw --direct=0 --size=$filesize --numjobs=$procs --directory=/$mpt  --minimal --fadvise_hint=$fadvise --clocksource=clock_gettime --rwmixread=$percentread --rwmixwrite=$percentwrite --pre_read=1 ",

"fio --name=seqmixedmmap-partialcache1 --ioengine=mmap --rw=rw --direct=0 --size=$filesize --numjobs=$procs --directory=/$mpt  --minimal --fadvise_hint=$fadvise --clocksource=clock_gettime --rwmixread=$percentread --rwmixwrite=$percentwrite --random_distribution=$cachehit "
);

 # ---- IO Latency Tests
my @iolatencytests = (
"fio --name=read-latency1 --ioengine=libaio --rw=randread --direct=1 --size=$filesize --directory=/$mpt --iodepth=1 --minimal --fadvise_hint=$fadvise --clocksource=clock_gettime ",
"fio --name=write-latency1 --ioengine=libaio --rw=randwrite --direct=1 --size=$filesize --directory=/$mpt --iodepth=1 --minimal --fadvise_hint=$fadvise --clocksource=clock_gettime "
);

 # ---- direct IO  Tests
my @iodirecttests = (
"fio --name=read-direct1 --ioengine=libaio --rw=randread --direct=1 --size=$filesize --directory=/$mpt --iodepth=$iodepth --minimal --fadvise_hint=$fadvise --clocksource=clock_gettime ",
"fio --name=write-direct1 --ioengine=libaio --rw=randwrite --direct=1 --size=$filesize --directory=/$mpt --iodepth=$iodepth --minimal --fadvise_hint=$fadvise --clocksource=clock_gettime "
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
  if((! -e "/sbin/mkfs.$filesystem") && ($filesystem !~ /nfs/)){
   print "$filesystem is not installed. Please install $filesystem package\n"; 
   exit;
  }
  print "filesystem selected: $filesystem \n";
  print "mount point selected:  $mpt \n";
  print "Devices selected: @devices \n\n";
  print "Setting up filesystem: $filesystem\n";
  setup_filesystem($filesystem,$mpt,\@devices);
  my $output =`df -T`;
  print "Please check if output matches your request:\n $output\n";

  $same = $start;  # To make it look like all file system tests started at the time. Useful for comparision in graph   

  my @args = ("./sysio.pl", "$same", "$filesystem");
    if (my $pid = fork) {
      #  waitpid($pid);  
    }
    else {
      exec(@args);
  }
  #my @args = ("./iolatency.pl", "$same", "$filesystem");
  #  if (my $pid = fork) {
  #    #  waitpid($pid);  
  #  }
  #  else {
  #    exec(@args);
  #}
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
        while ($loops-- > 0 ){ # perform each test with various block sizes. Repeat for $iteration 
          
          open (FIO, $temp) || die print "failed to get data: $!\n";
          while (<FIO>) {
           @stats= split(/;/);
           push @rtot,$stats[5];
           push @rbw,$stats[6];
           push @riops,$stats[7];
           push @wtot,$stats[46];
           push @wbw,$stats[47];
           push @wiops,$stats[48];
           push @rlatency,$stats[39];
           push @wlatency,$stats[80];
          }
          close(FIO);
	   # Sum it
	  my $rtot;
          grep { $rtot += $_ } @rtot;

	  my $rbw;
          grep { $rbw += $_ } @rbw;

 	  my $riops;
          grep { $riops += $_ } @riops;

          my $wtot;
          grep { $wtot += $_ } @wtot;

          my $wbw;
          grep { $wbw += $_ } @wbw;

          my $wiops;
          grep { $wiops += $_ } @wiops;

	  # calculate 99th percetile latency
          @rlatency = sort {$a <=> $b} @rlatency;
          $rlatency = $rlatency[sprintf("%.0f",(0.99*($#rlatency)))]; 

          @wlatency = sort {$a <=> $b} @wlatency;
          $wlatency = $wlatency[sprintf("%.0f",(0.99*($#wlatency)))]; 


	
          if (($stats[2] =~ /latency/) || ($stats[2] =~ /direct/)){
              @data = populate_data($server,$host,$size,$same,$mpt,$filesystem,$stats[2],$rotot,$rbw,$riops,$wtot,$wbw,$wiops,$rlatency, $wlatency, $stats[121]);
	  }
          else {
             @data = populate_data($server,$host,$size,$same,$mpt,$filesystem,$stats[2],$rotot,$rbw,$riops,$wtot,$wbw,$wiops,$rlatency, $wlatency, $stats[121]);
          }

          print @data;                            # For Testing only 
          print "\n------\n";                     # For Testing only
          print GRAPHITE  @data;                  # Ship metrics to carbon server

          @data=();                               # Initialize for next set of metrics
 	  @stats=();
          @rtot=();
          @rbw=();
          @riops=();
          @wtot=();
          @wbw=();
          @wiops=();
	  @rlatency=();
	  @wlatency=();

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
        }  # Test for each block
    $loops=$iterations;
    #$same=$start;    		# Uncomment it to show the test with all blocks in the same time window. 
   } # Single Test completed with all blocks
  print "Completed All iteration of Test $test with blocks: @blocks\n";
  print "Removing test files: /$mpt/$word[1]\n";
  `sudo rm /$mpt/$word[1]*`;
  #$same=$start;		# Uncomment it to show all tests for perticular filesystem in one time window 
  } # All Tests completed for a perticular fileystem type
  `pkill -9 sysio.pl`; `pkill -9 iolatency.pl`;
 } # All Tests completed for all filesystem type
print "Completed: All Tests\n @alltests\n";
close (GRAPHITE);

