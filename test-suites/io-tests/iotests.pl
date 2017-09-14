#!/usr/bin/perl 

#use warnings;
#use strict;

#use Data::Dump qw(dump);
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
my $randreadnocache = "fio --name=randread-nocache --ioengine=libaio --rw=randread --direct=0 --size=$filesize --numjobs=$procs --iodepth=$iodepth --directory=/$mpt --minimal --fadvise_hint=$fadvise --clocksource=clock_gettime ";

my $randreadpartialcache = "fio --name=randread-partialcache --ioengine=libaio --rw=randread --direct=0 --size=$filesize --numjobs=$procs --iodepth=$iodepth --directory=/$mpt  --minimal --fadvise_hint=$fadvise --clocksource=clock_gettime --random_distribution=$cachehit ";

my $randreadfullcache = "fio --name=randread-fullcache --ioengine=libaio --rw=randread --direct=0 --size=$filesize --numjobs=$procs --iodepth=$iodepth --directory=/$mpt  --minimal --fadvise_hint=$fadvise --clocksource=clock_gettime --pre_read=1";

# ---- Sequential Read Tests
my $seqreadnocache = "fio --name=seqread-nocache --ioengine=libaio --rw=read --direct=0 --size=$filesize --numjobs=$procs  --iodepth=$iodepth --directory=/$mpt --minimal --fadvise_hint=$fadvise --clocksource=clock_gettime ";

my $seqreadpartialcache ="fio --name=seqread-partialcache --ioengine=libaio --rw=read --direct=0 --size=$filesize --numjobs=$procs --iodepth=$iodepth --directory=/$mpt  --minimal --fadvise_hint=$fadvise --clocksource=clock_gettime --random_distribution=$cachehit ";

my $seqreadfullcache = "fio --name=seqread-fullcache --ioengine=libaio --rw=read --direct=0 --size=$filesize --numjobs=$procs --iodepth=$iodepth --directory=/$mpt  --minimal --fadvise_hint=$fadvise --clocksource=clock_gettime --pre_read=1";


# ---- Random Write Tests
my $randwritenocache = "fio --name=randwrite-nocache --ioengine=libaio --rw=randwrite --direct=0 --size=$filesize --numjobs=$procs --iodepth=$iodepth --directory=/$mpt  --minimal --fadvise_hint=$fadvise --end_fsync=$end_fsync --clocksource=clock_gettime ";

my $randwritepartialcache = "fio --name=randwrite-partialcache --ioengine=libaio --rw=randwrite --direct=0 --size=$filesize --numjobs=$procs --iodepth=$iodepth --directory=/$mpt  --minimal --fadvise_hint=$fadvise --clocksource=clock_gettime --random_distribution=$cachehit ";

my $randwritefullcache = "fio --name=randwrite-fullcache --ioengine=libaio --rw=randwrite --direct=0 --size=$filesize --numjobs=$procs --iodepth=$iodepth --directory=/$mpt  --minimal --fadvise_hint=$fadvise --clocksource=clock_gettime --pre_read=1 ";

my $randwritefsycn = "fio --name=randwrite-fsync --fsync=32 --ioengine=libaio --rw=randwrite --direct=0 --size=$filesize --numjobs=$procs --iodepth=$iodepth --directory=/$mpt --minimal --fadvise_hint=$fadvise --clocksource=clock_gettime ";

my $randwritesynchronous = "fio --name=randwrite-Synchronous --sync=1 --ioengine=libaio --rw=randwrite --direct=0 --size=$filesize --numjobs=$procs --iodepth=$iodepth --directory=/$mpt --minimal --fadvise_hint=$fadvise --clocksource=clock_gettime ";

 # ---- Sequential Write Tests
my $seqwritenocache = "fio --name=seqwrite-nocache --ioengine=libaio --rw=write --direct=0 --size=$filesize --numjobs=$procs --directory=/$mpt  --minimal --fadvise_hint=$fadvise --end_fsync=$end_fsync --clocksource=clock_gettime ";

my $seqwritepartialcache = "fio --name=seqwrite-partialcache --ioengine=libaio --rw=write --direct=0 --size=$filesize --numjobs=$procs --directory=/$mpt  --minimal --fadvise_hint=$fadvise --clocksource=clock_gettime --random_distribution=$cachehit ";

my $seqwritefullcache = "fio --name=seqwrite-fullcache --ioengine=libaio --rw=write --direct=0 --size=$filesize --numjobs=$procs --directory=/$mpt  --minimal --fadvise_hint=$fadvise --clocksource=clock_gettime --pre_read=1";

my $seqwritefsync = "fio --name=seqwrite-fsync --fsync=32 --ioengine=libaio --rw=write --direct=0 --size=$filesize --numjobs=$procs --directory=/$mpt --minimal --fadvise_hint=$fadvise --clocksource=clock_gettime ";

my $seqwritesynchronous = "fio --name=seqwrite-Synchronous --sync= --ioengine=libaio --rw=write --direct=0 --size=$filesize --numjobs=$procs --directory=/$mpt --minimal --fadvise_hint=$fadvise --clocksource=clock_gettime ";

# ---- Random  Mixed Tests
my $randmixednocache =  "fio --name=randmixed-nocache --ioengine=libaio --rw=randrw --direct=0 --size=$filesize --numjobs=$procs --iodepth=$iodepth --directory=/$mpt  --minimal --fadvise_hint=$fadvise --end_fsync=$end_fsync --clocksource=clock_gettime --rwmixread=$percentread --rwmixwrite=$percentwrite ";

# ---- Sequential Mixed Tests
my $seqmixednocache = "fio --name=seqmixed-nocache --ioengine=libaio --rw=rw --direct=0 --size=$filesize --numjobs=$procs --directory=/$mpt  --minimal --fadvise_hint=$fadvise --end_fsync=$end_fsync --clocksource=clock_gettime --rwmixread=$percentread --rwmixwrite=$percentwrite ";

# ---- IO Latency Tests
my $iolatencyread = "fio --name=read-latency --ioengine=libaio --rw=randread --direct=1 --size=$filesize --directory=/$mpt --iodepth=1 --numjobs=$procs --minimal --fadvise_hint=$fadvise --clocksource=clock_gettime ";

my $iolatencywrite = "fio --name=write-latency --ioengine=libaio --rw=randwrite --direct=1 --size=$filesize --directory=/$mpt --iodepth=1 --numjobs=$procs --minimal --fadvise_hint=$fadvise --clocksource=clock_gettime ";

 # ---- direct IO  Tests
my $iodirectread = "fio --name=read-direct --ioengine=libaio --rw=randread --direct=1 --size=$filesize --directory=/$mpt --iodepth=$iodepth --numjobs=$procs --minimal --fadvise_hint=$fadvise --clocksource=clock_gettime ";

my $iodirectwrite = "fio --name=write-direct --ioengine=libaio --rw=randwrite --direct=1 --size=$filesize --directory=/$mpt --iodepth=$iodepth --numjobs=$procs --minimal --fadvise_hint=$fadvise --clocksource=clock_gettime ";

# push requested tests into an @alltests array

if ($iolatencyreadtest == 1) { push (@alltests, $iolatencyread);}
if ($iolatencywritetest ==1) { push (@alltests, $iolatencywrite);}

if ($iodirectreadtest ==1) { push (@alltests, $iodirectread);}
if ($iodirectwritetest ==1) { push (@alltests, $iodirectwrite);}

if ($randreadnocachetest == 1 ) { push (@alltests, $randreadnocache); }
if ($randreadpartialcachetest == 1 ) { push (@alltests, $randreadpartialcache); }
if ($randreadfullcachetest == 1 ) { push (@alltests, $randreadfullcache); }

if ($seqreadnocachetest == 1)  { push (@alltests, $seqreadnocache);  }
if ($seqreadpartialcachetest == 1)  { push (@alltests, $seqreadpartialcache);  }
if ($seqreadfullcachetest == 1)  { push (@alltests, $seqreadfullcache);  }

if ($randwritenocachetest == 1) { push (@alltests, $randwritenocache);}
if ($randwritepartialcachetest == 1) { push (@alltests, $randwritepartialcache);}
if ($randwritefullcachetest == 1) { push (@alltests, $randwritefullcache);}
if ($randwritefsynctest == 1) { push (@alltests, $randwritefsync);}
if ($randwritesynchronoustest == 1) { push (@alltests, $randwritesynchronous);}

if ($seqwritenocachetest == 1)  { push (@alltests, $seqwritenocache); }
if ($seqwritepartialcachetest == 1)  { push (@alltests, $seqwritepartialcache); }
if ($seqwritefullcachetest == 1)  { push (@alltests, $seqwritefullcache); }
if ($seqwritefsynctestt == 1)  { push (@alltests, $seqwritefsync); }
if ($seqwritesynchronoustest == 1)  { push (@alltests, $seqwritesynchronous); }

if ($randmixednocachetest == 1)  { push (@alltests, $randmixednocache);}
if ($seqmixednocachetest == 1)  { push (@alltests, $seqmixednocache); }


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
my @rlatency99th;
my @wlatency99th;
my @rtotlatency;
my @wtotlatency;
my $testfiles;
my $loops=$iterations;
my $same;
my $flag=0;
my $start = `date +%s`;

# Make sure to stop Linux perf tracing for general purpse system monitoring. We will be doing it in the test context.
  `sudo pkill -9 loop-iolatency`;
  `sudo pkill -9 iolatency.pl`;

foreach $filesystem (@filesystems){  # Run tests against all filesystem requested
  if((! -e "/sbin/mkfs.$filesystem") && ($filesystem !~ /nfs/) && ($filesystem !~ /zfs/)){
   print "$filesystem is not installed. Please install $filesystem package\n"; 
   exit;
  }
  print "filesystem selected: $filesystem \n";
  print "mount point selected:  $mpt \n";
  print "Devices selected: @devices \n\n";
  print "Setting up filesystem: $filesystem\n";
  setup_filesystem($filesystem,$mpt,\@devices);
  my $output =`df -T`;
  print "Please check if requested filesystem $filesystem is mounted correctly on $mpt:\n $output\n";

  $same = $start;  # To make it look like all file system tests started at the time. Useful for comparision in graph   
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
           push @rlatency,$stats[14];
           push @wlatency,$stats[55];
           @stats99 = split('=', $stats[29]), 
 #99.000000%=7840
           push @rlatency99th,$stats99[1];
           @stats99 = split('=', $stats[70]), 
           push @wlatency99th,$stats99[1];
           push @rtotlatency,$stats[38];
           push @wtotlatency,$stats[79];
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

          @rlatency99th = sort {$a <=> $b} @rlatency99th;
          $rlatency99th= $rlatency99th[sprintf("%.0f",(0.99*($#rlatency99th)))]; 

          @wlatency99th = sort {$a <=> $b} @wlatency99th;
          $wlatency99th = $wlatency99th[sprintf("%.0f",(0.99*($#wlatency99th)))]; 

          @rtotlatency = sort {$a <=> $b} @rtotlatency;
          $rtotlatency= $rtotlatency[sprintf("%.0f",(0.99*($#rtotlatency)))]; 

          @wtotlatency = sort {$a <=> $b} @wtotlatency;
          $wtotlatency = $wtotlatency[sprintf("%.0f",(0.99*($#wtotlatency)))]; 


	  # ZFS does not release memory in ARC. Throwing away the first test result
	  if (($filesystem =~ /zfs/) && ($loops == $iterations-1) && ($flag == 0)) {
              $loops = $iterations;  # This will make sure we run same number of iterations with ZFS
	      $flag = 1;
	  }
         else {
           @data = populate_data($server,$host,$size,$same,$mpt,$filesystem,$stats[2],$rtot,$rbw,$riops,$wtot,$wbw,$wiops,$rlatency,$wlatency,$rlatency99th,$wlatency99th,$rtotlatency,$wtotlatency,$stats[121]);
           #@data = populate_data($server,$host,$size,$same,$mpt,$filesystem,$stats[2],$rotot,$rbw,$riops,$wtot,$wbw,$wiops,$rlatency,$wlatency,$stats[121]);
          #print @data;                            # For Testing only 
          #print "\n------\n";                     # For Testing only
          print GRAPHITE  @data;                  # Ship metrics to carbon server
	  }

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
	  @rlatency99th=();
	  @wlatency99th=();
	  @rtotlatency=();
	  @wtotlatency=();

          $same = $same + 5;
	  # Need to release memory from ZFS ARC after every test run. 
          if ($filesystem =~ /zfs/) { 
           #my $output =`cat /proc/spl/kstat/zfs/arcstats|grep ^size`;
           #print "ZFS ARC Size Before:$output\n";
           `sudo zpool export pool`;
           `sudo zpool import pool`;
           #my $output =`cat /proc/spl/kstat/zfs/arcstats|grep ^size`;
           #print "ZFS ARC Size After: $output\n";
          }
        }  # Test for each block
    $loops=$iterations;
    $same=$start;    		# Uncomment it to show the test with all blocks in the same time window. 
   } # Single Test completed with all blocks
  print "Completed All iteration of Test $test with blocks: @blocks\n";
  print "Removing test files: /$mpt/$word[1]\n";
  `sudo rm /$mpt/$word[1]*`;
  $same=$start;		# Uncomment it to show all tests for perticular filesystem in one time window 
  } # All Tests completed for a perticular fileystem type
   `pkill -9 sysio.pl`; `pkill -9 iolatency.pl`;
 } # All Tests completed for all filesystem type
print "Completed: All Tests\n @alltests\n";
close (GRAPHITE);
