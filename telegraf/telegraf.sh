#!/bin/bash

# USER INFORMATION #############################################
TELEGRAF_VERSION="1.21.2-1_amd64" # Telegraf Version
VROCP_HOSTNAME="" # vRealize Operations Cloud Proxy Hostname
VROPS_HOSTNAME="" # vRealize Operations Hostname
VROPS_USERNAME="" # vRealize Operations Username
VROPS_PASSWORD="" # vRealize Operations Password
################################################################

apt install -y jq
wget https://dl.influxdata.com/telegraf/releases/telegraf_$TELEGRAF_VERSION.deb -O /tmp/telegraf.deb
dpkg -i /tmp/telegraf.deb
wget --no-check-certificate https://$VROCP_HOSTNAME/downloads/salt/open_source_telegraf_monitor.sh -O /tmp/telegraf.sh
chmod 755 /tmp/telegraf.sh
TOKEN=$(curl -k -XPOST "https://$VROPS_HOSTNAME/suite-api/api/auth/token/acquire" -H "Content-Type: application/json" -H "Accept: application/json" -d "{\"username\":\"$VROPS_USERNAME\",\"authSource\":\"Local\",\"password\":\"$VROPS_PASSWORD\"}" | jq ".token" | sed "s/\"//g")
/tmp/telegraf.sh -v $VROPS_HOSTNAME -t $TOKEN -c $VROCP_HOSTNAME -d /etc/telegraf/telegraf.d -e /usr/bin/telegraf
sed -i "s/^\[\[outputs\.influxdb\]\]/#\[\[outputs\.influxdb\]\]/g" /etc/telegraf/telegraf.conf
systemctl restart telegraf