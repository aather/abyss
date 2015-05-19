#!/bin/bash
# Run as root or sudo 
# This script will install carbon graphite, apache2 and elastic search components and configure them
# Caution: It may over write your local carbon, apache2 and elastic search configuration
export DEBIAN_FRONTEND=noninteractive
sudo apt-get update
sudo apt-get install -q -y graphite-carbon
sudo apt-get install -q -y graphite-web
sudo apt-get -y install apache2 apache2-mpm-worker libapache2-mod-wsgi
service carbon-cache stop
echo "CARBON_CACHE_ENABLED=true" > /etc/default/graphite-carbon
cp /etc/carbon/carbon.conf /etc/carbon/carbon.conf-ORIG
cp carbon.conf.custom /etc/carbon/carbon.conf
cp /etc/carbon/storage-schemas.conf /etc/carbon/storage-schemas.conf-ORIG
cp storage-schemas.conf.custom /etc/carbon/storage-schemas.conf
# uncomment lines below if interested in installing whisper database in non-default place
#-------
#sudo rm -r /var/lib/graphite/whisper
#sudo mkdir /mnt/whisper
#sudo chown -R _graphite /mnt/whisper
#sudo chgrp -R _graphite /mnt/whisper
#sudo ln -s /mnt/whisper /var/lib/graphite/whisper
#--------
sudo -u _graphite graphite-manage syncdb --noinput
cp /etc/apache2/sites-enabled/000-default.conf /etc/apache2/sites-enabled/000-default.conf-ORIG
rm -f /etc/apache2/sites-enabled/000-default.conf
cp /usr/share/graphite-web/apache2-graphite.conf /etc/apache2/sites-enabled/graphite.conf
service apache2 restart
curl -s http://packages.elasticsearch.org/GPG-KEY-elasticsearch | apt-key add -
echo "deb http://packages.elasticsearch.org/elasticsearch/1.0/debian stable main" > /etc/apt/sources.list.d/elasticsearch.list
update-rc.d elasticsearch defaults
cp /etc/elasticsearch/elasticsearch.yml /etc/elasticsearch/elasticsearch.yml-ORIG
cp elasticsearch.yml.custom /etc/elasticsearch/elasticsearch.yml
service elasticsearch start
cp grafana.tar /usr/share/
tar -xvf /usr/share/grafana.tar
cp config.js.custom /usr/share/grafana/config.js
echo "alias /grafana /usr/share/grafana" > /etc/apache2/sites-enabled/grafana.conf
service apache2 restart
service elasticsearch restart
service carbon-cache restart 
cp crontab-root.custom /var/spool/cron/crontabs/root
service cron restart
