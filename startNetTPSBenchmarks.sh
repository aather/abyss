#!/bin/bash
cd ./test-suites/net-tests/micro-benchmarks
while :			
do					
 nohup ./netTPS.pl &		
 nohup ./pingRTT.pl
done
