#!/bin/bash

while :
do
	./kafka.pl
	sleep 5
	echo "Restarting kafka.pl"
done

