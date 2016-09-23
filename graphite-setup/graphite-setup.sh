#!/bin/bash
DIR=`pwd`
# Run as root or sudo 
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi
# This script will install carbon graphite, apache2 and grafana server and configure them
# Caution: It may over write your local carbon and apache2  configuration
export DEBIAN_FRONTEND=noninteractive
sudo apt-get update
# install graphite and apache packages
sudo apt-get install -q -y graphite-carbon
sudo apt-get install -q -y graphite-web
sudo apt-get -y install apache2 libapache2-mod-wsgi
service carbon-cache stop
echo "CARBON_CACHE_ENABLED=true" > /etc/default/graphite-carbon
if [ -e "/etc/carbon/carbon.conf" ]
then
cp /etc/carbon/carbon.conf /etc/carbon/carbon.conf-ORIG
fi
cp ./carbon.conf.custom /etc/carbon/carbon.conf
if [ -e "/etc/carbon/storage-schemas.conf" ]
then
cp /etc/carbon/storage-schemas.conf /etc/carbon/storage-schemas.conf-ORIG
fi
cp ./storage-schemas.conf.custom /etc/carbon/storage-schemas.conf
# uncomment lines below if interested in installing whisper database in non-default place
#-------
#sudo rm -r /var/lib/graphite/whisper
#sudo mkdir -p /mnt/whisper
#sudo chown -R _graphite /mnt/whisper
#sudo chgrp -R _graphite /mnt/whisper
#sudo ln -s /mnt/whisper /var/lib/graphite/whisper
#--------
sudo -u _graphite graphite-manage syncdb --noinput
if [ -e "/etc/apache2/sites-enabled/000-default.conf" ]
then
cp /etc/apache2/sites-enabled/000-default.conf /etc/apache2/sites-enabled/000-default.conf-ORIG
fi
rm -f /etc/apache2/sites-enabled/000-default.conf
if [ -e "/etc/apache2/sites-enabled/graphite.conf" ]
then
cp /etc/apache2/sites-enabled/graphite.conf /etc/apache2/sites-enabled/graphite.conf-ORIG
fi
cp ./graphite.conf.custom /etc/apache2/sites-enabled/graphite.conf
sudo ln -sf /etc/apache2/mods-available/headers.load /etc/apache2/mods-enabled/headers.load
sudo cp -r ./grafana /usr/share/
cd /usr/share/grafana/bin
sudo nohup ./grafana-server &
sudo service apache2 restart
sudo service carbon-cache restart 
# Install crontab file to remove metrics that are not being updated
if [ -e "/var/spool/cron/crontabs/root" ]
then 
sudo cp /var/spool/cron/crontabs/root /var/spool/cron/crontabs/root-ORIG
fi
cd $DIR
sudo cp ./crontab-root.custom /var/spool/cron/crontabs/root
sudo service cron restart
sudo netstat -ltpn 

