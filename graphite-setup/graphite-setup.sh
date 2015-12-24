#!/bin/bash
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
sudo apt-get -y install apache2 apache2-mpm-worker libapache2-mod-wsgi
service carbon-cache stop
echo "CARBON_CACHE_ENABLED=true" > /etc/default/graphite-carbon
cp /etc/carbon/carbon.conf /etc/carbon/carbon.conf-ORIG
cp ./carbon.conf.custom /etc/carbon/carbon.conf
cp /etc/carbon/storage-schemas.conf /etc/carbon/storage-schemas.conf-ORIG
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
cp /etc/apache2/sites-enabled/000-default.conf /etc/apache2/sites-enabled/000-default.conf-ORIG
rm -f /etc/apache2/sites-enabled/000-default.conf
#cp /usr/share/graphite-web/apache2-graphite.conf /etc/apache2/sites-enabled/graphite.conf
# ----support ACAO headers
cp ./graphite.conf.custom /etc/apache2/sites-enabled/graphite.conf
# ----load the header module to support ACAO headers
sudo ln -sf /etc/apache2/mods-available/headers.load /etc/apache2/mods-enabled/headers.load
#service apache2 restart
cp ./grafana.tar.gz /usr/share/
tar -zxvf /usr/share/grafana.tar.gz > /dev/null 2>&1
cd /usr/share/grafana/bin
nohup ./grafana-server start &
service apache2 restart
service carbon-cache restart 
service cron restart
sudo netstat -ltpn 
