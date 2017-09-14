#!/usr/bin/perl

package Common;
#use strict;
#use warnings;

use Exporter;
our @ISA= qw( Exporter );
our @EXPORT_OK = qw( populate_data signal_handler );
our @EXPORT = qw( populate_data singal_handler );

sub populate_data {
  my ($server, $host, $block, $now, $mpt, $filesystem,$name,$rtot, $rbw, $riops, $wtot, $wbw, $wiops, $rlatency, $wlatency,$rlatency99th, $wlatency99th, $mydev) = @_;
 $now = $now + 5;
 my @data = ();
 if ($filesystem =~ /zfs/){
   push @data, "$server-iobench.$host.benchmark.IO.$filesystem.$name.$block.pool.rtot $rtot $now \n";
   push @data, "$server-iobench.$host.benchmark.IO.$filesystem.$name.$block.pool.rbw $rbw $now \n";
   push @data, "$server-iobench.$host.benchmark.IO.$filesystem.$name.$block.pool.riops $riops $now \n";
   push @data, "$server-iobench.$host.benchmark.IO.$filesystem.$name.$block.pool.wtot $wtot $now \n";
   push @data, "$server-iobench.$host.benchmark.IO.$filesystem.$name.$block.pool.wbw $wbw $now \n";
   push @data, "$server-iobench.$host.benchmark.IO.$filesystem.$name.$block.pool.wiops $wiops $now \n";
   push @data, "$server-iobench.$host.benchmark.IO.$filesystem.$name.$block.pool.rlatency $rlatency $now \n";
   push @data, "$server-iobench.$host.benchmark.IO.$filesystem.$name.$block.pool.wlatency $wlatency $now \n";
   push @data, "$server-iobench.$host.benchmark.IO.$filesystem.$name.$block.pool.rlatency99th $rlatency99th $now \n";
   push @data, "$server-iobench.$host.benchmark.IO.$filesystem.$name.$block.pool.wlatency99th $wlatency99th $now \n";
 }
 elsif ($filesystem =~ /nfs/){   
   push @data, "$server-iobench.$host.benchmark.IO.$filesystem.$name.$block.$mpt.rtot $rtot $now \n";
   push @data, "$server-iobench.$host.benchmark.IO.$filesystem.$name.$block.$mpt.rbw $rbw $now \n";
   push @data, "$server-iobench.$host.benchmark.IO.$filesystem.$name.$block.$mpt.riops $riops $now \n";
   push @data, "$server-iobench.$host.benchmark.IO.$filesystem.$name.$block.$mpt.wtot $wtot $now \n";
   push @data, "$server-iobench.$host.benchmark.IO.$filesystem.$name.$block.$mpt.wbw $wbw $now \n";   
   push @data, "$server-iobench.$host.benchmark.IO.$filesystem.$name.$block.$mpt.wiops $wiops $now \n";
   push @data, "$server-iobench.$host.benchmark.IO.$filesystem.$name.$block.$mpt.rlatency $rlatency $now \n";
   push @data, "$server-iobench.$host.benchmark.IO.$filesystem.$name.$block.$mpt.wlatency $wlatency $now \n";
   push @data, "$server-iobench.$host.benchmark.IO.$filesystem.$name.$block.$mpt.rlatency99th $rlatency99th $now \n";
   push @data, "$server-iobench.$host.benchmark.IO.$filesystem.$name.$block.$mpt.wlatency99th $wlatency99th $now \n";
 }
 else {
   push @data, "$server-iobench.$host.benchmark.IO.$filesystem.$name.$block.$mydev.rtot $rtot $now \n";
   push @data, "$server-iobench.$host.benchmark.IO.$filesystem.$name.$block.$mydev.rbw $rbw $now \n";
   push @data, "$server-iobench.$host.benchmark.IO.$filesystem.$name.$block.$mydev.riops $riops $now \n";
   push @data, "$server-iobench.$host.benchmark.IO.$filesystem.$name.$block.$mydev.wtot $wtot $now \n";
   push @data, "$server-iobench.$host.benchmark.IO.$filesystem.$name.$block.$mydev.wbw $wbw $now \n";
   push @data, "$server-iobench.$host.benchmark.IO.$filesystem.$name.$block.$mydev.wiops $wiops $now \n";
   push @data, "$server-iobench.$host.benchmark.IO.$filesystem.$name.$block.$mydev.rlatency $rlatency $now \n";
   push @data, "$server-iobench.$host.benchmark.IO.$filesystem.$name.$block.$mydev.wlatency $wlatency $now \n";
   push @data, "$server-iobench.$host.benchmark.IO.$filesystem.$name.$block.$mydev.rlatency99th $rlatency99th $now \n";
   push @data, "$server-iobench.$host.benchmark.IO.$filesystem.$name.$block.$mydev.wlatency99th $wlatency99th $now \n";
 }
 return @data;
}

1;
