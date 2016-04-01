#!/bin/bash
#
# Setup everything
#

if [ $(id -u) != 0 ]; then
    echo "ERROR: $0 must be be run as root, not as `whoami`" 2>&1
    exit 1
fi

DEBIAN_FRONTEND=noninteractive

if [[ -f /home/vagrant/bin/meteo.sh ]]; then
    echo "Skipping setup..."
else
    echo "Running setup..."    
    apt-get update
    apt-get -y install cutycapt imagemagick xvfb fonts-liberation cron coreutils

    # configure cron
    echo Europe/Zurich | sudo tee /etc/timezone && sudo dpkg-reconfigure --frontend noninteractive tzdata
    cp /vagrant/files/crontabs/vagrant /var/spool/cron/crontabs/vagrant
    chown vagrant:crontab /var/spool/cron/crontabs/vagrant
    chmod 0600 /var/spool/cron/crontabs/vagrant

    cp /vagrant/files/crontabs/vagrant /var/spool/cron/crontabs/vagrant
    mkdir -p /home/vagrant/bin
    cp /vagrant/scripts/meteo.sh /home/vagrant/bin/meteo.sh
fi

