#!/bin/bash

while :
do
	nohup ./cassandra20.pl
	sleep 5
	echo "Restarting cassandra20.pl"
done

