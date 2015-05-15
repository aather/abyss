#!/bin/bash

while :
do
	nohup ./systats.pl
	sleep 5
	echo "Restarting systats.pl"
done

