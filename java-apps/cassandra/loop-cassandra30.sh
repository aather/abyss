#!/bin/bash

while :
do
	nohup ./cassandra30.pl
	sleep 5
	echo "Restarting cassandra30.pl"
done

