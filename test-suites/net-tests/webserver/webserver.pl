#! /usr/bin/perl 
use Data::Dumper qw(Dumper);

#use warnings;
#use strict;
use Fcntl qw/:flock/;

open SELF, "< $0" or die ;
flock SELF, LOCK_EX | LOCK_NB  or die "Another instance of the same program is already running: $!";

require "../../../env.pl";                            # Sets up environment varilables for all agents

#setpriority(0,$$,19);                          # Uncomment if running script at a lower priority

#$SIG{INT} = \&signal_handler;
#$SIG{TERM} = \&signal_handler;

my @data = ();                                  # array to store metrics
# ------------------------------agent specific -------------------

my @stats;
my @percentile;
my %hash;
my $total;
my $i=0;
my $exit;

# open a connection to graphite server
open(GRAPHITE, "| ../../../common/nc -w 600 $carbon_server $carbon_port") || die "failed to send: $!\n";

# Plan is to keep all RPS rates within the same time frame
my $time = `date +%s`;
my $now = $time;
#my $loops = $iterations;

my @args = ("./sysweb.pl", "$now", "$connections");
  if (my $pid = fork) {
     # No waiting for child 
     #  waitpid($pid);  
  }
  else {
     # I am child, now execute external command in context of new process.
     exec(@args);
  }

foreach my $connections (@CONNECTIONS){
  while ($loops-- > 0 ) {
  open (INTERFACE, "../../../common/wrk --latency -t $wthreads -c $connections -d 60s http://$peer:$webserver_port/$filename |")|| die print "failed to get data: $!\n";
   while (<INTERFACE>) {
     next if ((/^$/) || (/Latency/) || (/Req\/Sec/));
     if ((/50%/) ||( /75%/) ||( /90%/) ||( /99%/)){
       @stats = split;
       if ($stats[1] =~ /us/){
        $stats[1] =~ s/[us]+/ /g;   # remove us from the string
	$stats[1] = $stats[1] / 1000;
	push @data, "$server-netbench.$host.benchmark.webserver.$stats[0] $stats[1]  $now \n";
	}
       if ($stats[1] =~ /ms/){
        $stats[1] =~ s/[ms]+/ /g;   # remove us from the string
	push @data, "$server-netbench.$host.benchmark.webserver.$stats[0] $stats[1]  $now \n";
	}
     }
   if (/^Requests/){
	@stats = split /:/;
	$stats[1] =~ s/^\s+|\s+$//g;    # removing spaces from front and back
	push @data, "$server-netbench.$host.benchmark.webserver.RPS $stats[1]  $now \n";
   }
  }
  close(INTERFACE);
  #print @data; 			# For Testing only 
  #print "\n------\n"; 			# For Testing only
  print GRAPHITE  @data;  		# Ship metrics to graphite carbon server

  @data=();     			# Initialize for next set of metrics
  $now = $now + 5;  # Make it look like sample is shipped every 5 seconds
 }
  $loops=$iterations;
}
  `pkill -9 sysweb.pl`;

