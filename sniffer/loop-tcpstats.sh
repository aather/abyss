#!/bin/bash

while :
do
	nohup ./tcpstats.pl
	sleep 5
	echo "Restarting tcpstats.pl"
done

