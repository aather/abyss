#!/bin/bash
# Run as root or sudo 
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi
# This script will install carbon graphite, apache2 and elastic search components and configure them
# Caution: It may over write your local carbon, apache2 and elastic search configuration
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
service apache2 restart
# ----install 
curl -s http://packages.elasticsearch.org/GPG-KEY-elasticsearch | apt-key add -
echo "deb http://packages.elasticsearch.org/elasticsearch/1.0/debian stable main" > /etc/apt/sources.list.d/elasticsearch.list
update-rc.d elasticsearch defaults
cp /etc/elasticsearch/elasticsearch.yml /etc/elasticsearch/elasticsearch.yml-ORIG
cp ./elasticsearch.yml.custom /etc/elasticsearch/elasticsearch.yml
service elasticsearch start
cp ./grafana.tar /usr/share/
tar -xvf /usr/share/grafana.tar > /dev/null 2>&1
cp ./config.js.custom /usr/share/grafana/config.js
echo "alias /grafana /usr/share/grafana" > /etc/apache2/sites-enabled/grafana.conf
# ----copy dashboards. Open it from browser: http://hostname/grafana/#/dashboard/file/System.json
# cp ../Dashboards/Abyss-Menu.json /usr/share/grafana/app/dashboards/default.json
cp ../Dashboards/System.json /usr/share/grafana/app/dashboards/System.json
cp ../Dashboards/Cassandra.json /usr/share/grafana/app/dashboards/Cassandra.json
cp ../Dashboards/Tomcat.json /usr/share/grafana/app/dashboards/Tomcat.json
cp ../Dashboards/Kafka.json /usr/share/grafana/app/dashboards/Kafka.json
cp ../Dashboards/Benchmark.json /usr/share/grafana/app/dashboards/Benchmark.json
chmod 644 /usr/share/grafana/app/dashboards/*.json
service apache2 restart
service elasticsearch restart
service carbon-cache restart 
cp crontab-root.custom /var/spool/cron/crontabs/root
service cron restart
sudo netstat -ltpn 
echo "***********************************"
echo ""
echo "To open dashboard, type into browser" 
echo "System Dashboard: http://hostname/grafana/#/dashboard/file/System.json"
echo "Benchmark Dashboard: http://hostname/grafana/#/dashboard/file/Benchmark.json"
echo "System Dashboard: http://hostname/grafana/#/dashboard/file/Tomcat.json"
echo "System Dashboard: http://hostname/grafana/#/dashboard/file/Cassandra.json"
echo "System Dashboard: http://hostname/grafana/#/dashboard/file/Kafka.json"
echo ""
echo "******************************************"
