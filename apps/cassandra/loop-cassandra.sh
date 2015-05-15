#!/bin/bash

while :
do
	nohup ./cassandra.pl
	sleep 5
	echo "Restarting cassandra.pl"
done

