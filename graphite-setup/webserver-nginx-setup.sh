#!/bin/bash
# This script will install nginx webserver and set it up to run webserver benchmark
# Caution: It may over write your local nginx configuration
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root: sudo -s" 1>&2
   exit 1
fi
export DEBIAN_FRONTEND=noninteractive
curl http://nginx.org/keys/nginx_signing.key | apt-key add -
echo -e "deb http://nginx.org/packages/mainline/ubuntu/ `lsb_release -cs` nginx\ndeb-src http://nginx.org/packages/mainline/ubuntu/ `lsb_release -cs` nginx" > /etc/apt/sources.list.d/nginx.list
apt-get update
apt-get install -q -y nginx
cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf-ORIG
cp nginx.conf-sample-nginx /etc/nginx/nginx.conf
cp /etc/nginx/conf.d/default.conf /etc/nginx/conf.d/default.conf-ORIG
cp default.conf-sample-nginx /etc/nginx/conf.d/
service nginx start
sudo netstat -ltpn 
nginx -v
