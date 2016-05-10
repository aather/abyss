#!/usr/bin/perl

package Common;
#use strict;
#use warnings;

use Exporter;
our @ISA= qw( Exporter );
our @EXPORT_OK = qw( populate_data signal_handler );
our @EXPORT = qw( populate_data singal_handler );

sub populate_data {
  my ($server, $host, $block, $now, $filesystem, $procs,$name,$rtot, $rbw, $riops, $wtot, $wbw, $wiops, $rlatency, $wlatency, $mydev) = @_;
 $now = $now + 5;
 my @data = ();
 if ($filesystem =~ /zfs/){
   $rtot = $rtot * $procs;
   push @data, "$server-iobench.$host.benchmark.IO.$filesystem.$name.$block.pool.rtot $rtot $now \n";
   $rbw = $rbw * $procs;
   push @data, "$server-iobench.$host.benchmark.IO.$filesystem.$name.$block.pool.rbw $rbw $now \n";
   $riops = $riops * $procs;
   push @data, "$server-iobench.$host.benchmark.IO.$filesystem.$name.$block.pool.riops $riops $now \n";
   $wtot = $wtot * $procs;
   push @data, "$server-iobench.$host.benchmark.IO.$filesystem.$name.$block.pool.wtot $wtot $now \n";
   $wbw = $wbw * $procs;
   push @data, "$server-iobench.$host.benchmark.IO.$filesystem.$name.$block.pool.wbw $wbw $now \n";
   $wiops = $wiops * $procs;
   push @data, "$server-iobench.$host.benchmark.IO.$filesystem.$name.$block.pool.wiops $wiops $now \n";
   $rlatency = $rlatency * $procs;
   push @data, "$server-iobench.$host.benchmark.IO.$filesystem.$name.$block.pool.rlatency $rlatency $now \n";
   $wlatency = $wlatency * $procs;
   push @data, "$server-iobench.$host.benchmark.IO.$filesystem.$name.$block.pool.wlatency $wlatency $now \n";
 }
 else {
   $rtot = $rtot * $procs;
   push @data, "$server-iobench.$host.benchmark.IO.$filesystem.$name.$block.$mydev.rtot $rtot $now \n";
   $rbw = $rbw * $procs;
   push @data, "$server-iobench.$host.benchmark.IO.$filesystem.$name.$block.$mydev.rbw $rbw $now \n";
   $riops = $riops * $procs;
   push @data, "$server-iobench.$host.benchmark.IO.$filesystem.$name.$block.$mydev.riops $riops $now \n";
   $wtot = $wtot * $procs;
   push @data, "$server-iobench.$host.benchmark.IO.$filesystem.$name.$block.$mydev.wtot $wtot $now \n";
   $wbw = $wbw * $procs;
   push @data, "$server-iobench.$host.benchmark.IO.$filesystem.$name.$block.$mydev.wbw $wbw $now \n";
   $wiops = $wiops * $procs;
   push @data, "$server-iobench.$host.benchmark.IO.$filesystem.$name.$block.$mydev.wiops $wiops $now \n";
   $rlatency = $rlatency * $procs;
   push @data, "$server-iobench.$host.benchmark.IO.$filesystem.$name.$block.$mydev.rlatency $rlatency $now \n";
   $wlatency = $wlatency * $procs;
   push @data, "$server-iobench.$host.benchmark.IO.$filesystem.$name.$block.$mydev.wlatency $wlatency $now \n";
 }
 return @data;
}

1;
