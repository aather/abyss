#!/bin/bash

while :
do
	nohup ./elasticsearch.pl
	sleep 5
	echo "Restarting elasticsearch.pl"
done

