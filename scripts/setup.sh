#!/bin/bash
#
# Setup everything
#

if [ $(id -u) != 0 ]; then
    echo "ERROR: $0 must be be run as root, not as `whoami`" 2>&1
    exit 1
fi

DEBIAN_FRONTEND=noninteractive

# Insert the meteo.sh script
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
    chown vagrant:vagrant -R /home/vagrant/*
fi

# Configure the upload host (web server)
CONFIG="/vagrant/config/server.inc"
if [[ -f ${CONFIG} ]]; then
    source ${CONFIG}
    CONFIG_ID="/home/vagrant/.$(cat ${CONFIG} | md5sum | cut -d ' ' -f1)_configuration_id"
    if [[ ! -f ${CONFIG_ID} ]]; then
        echo "Adding host >${SCP_HOST}< to known_hosts:"
        sudo -u vagrant sh -c "ssh-keyscan ${SCP_HOST}>> ~/.ssh/known_hosts && touch ${CONFIG_ID}"
    fi
    echo "Upload host configuration:"
    echo " SCP_HOST  : ${SCP_HOST}"
    echo " SCP_USER  : ${SCP_USER}"
    echo " SCP_PATH  : ${SCP_PATH}"
else
    echo
    echo "No upload host configuration found! Use the template and configure the upload host:"
    echo " cp ./config/server.inc.template ./config/server.inc"
    echo
    exit 1
fi

# Insert or generate the SSH keys for uploading the generated image
if [[ ! -f /home/vagrant/.ssh/id_rsa ]]; then
    mkdir -p /home/vagrant/.ssh
    chmod 0700 /home/vagrant/.ssh
    chown vagrant:vagrant /home/vagrant/.ssh
    CONFIG_KEY="/vagrant/config/id_rsa"
    CONFIG_KEYS="${CONFIG_KEY}*"
    if [[ -f ${CONFIG_KEY} ]]; then
        echo "Installing existing upload keys: ${CONFIG_KEYS}"
        cp -v ${CONFIG_KEYS} /home/vagrant/.ssh/
    else
        echo "Generating a new upload key pair..."
        sudo -u vagrant ssh-keygen -t rsa -b 4096 -C "meteo upload key" -P "meteokey" -f "/home/vagrant/.ssh/meteokey_enc"
        sudo -u vagrant openssl rsa -in /home/vagrant/.ssh/meteokey_enc -passin pass:meteokey -out /home/vagrant/.ssh/id_rsa
        sudo -u vagrant mv /home/vagrant/.ssh/meteokey_enc.pub /home/vagrant/.ssh/id_rsa.pub
        sudo -u vagrant cp -v /home/vagrant/.ssh/id_rsa* /vagrant/config
    fi
    chown vagrant:vagrant /home/vagrant/.ssh/*
    chmod 0600 /home/vagrant/.ssh/id_rsa
    chmod 0644 /home/vagrant/.ssh/id_rsa.pub
fi

if [[ ${SCP_HOST} == "localhost" ]]; then
    if [[ -e /home/vagrant/.ssh/id_rsa.pub ]]; then
        PUBLIC_KEY="$(cat /home/vagrant/.ssh/id_rsa.pub)"
        if grep -Fxq "${PUBLIC_KEY}" /home/vagrant/.ssh/authorized_keys
        then
            echo "Public Key /home/vagrant/.ssh/id_rsa.pub already in authorized_keys file."
        else
            echo "Adding Public Key /home/vagrant/.ssh/id_rsa.pub to authorized_keys file."
          echo "${PUBLIC_KEY}" >> /home/vagrant/.ssh/authorized_keys
          chmod 0600 /home/vagrant/.ssh/authorized_keys
          chown vagrant:vagrant /home/vagrant/.ssh/*
        fi
    fi
else
    echo "Make sure the public key is known by your server:"
    echo
    echo "   ssh-copy-id -i ./config/id_rsa.pub ${SCP_USER}@${SCP_HOST}"
    echo
fi

