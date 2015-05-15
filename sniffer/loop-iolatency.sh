#!/bin/bash

while :
do
        nohup ./iolatency.pl
        sleep 5
        echo "Restarting iolatency.pl"
done

