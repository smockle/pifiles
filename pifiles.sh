#!/usr/bin/env bash
set -eo pipefail

PIFILES_DIRECTORY=$(dirname "$(readlink -f "$0")")

# Add Docker repository
if [ ! -f /etc/apt/sources.list.d/docker.list ]; then
    curl -fsSL https://download.docker.com/linux/raspbian/gpg | sudo apt-key add -
    echo "deb [arch=armhf] https://download.docker.com/linux/raspbian stretch stable" | sudo tee /etc/apt/sources.list.d/docker.list
fi

# Update package lists
sudo apt-get update -y
sudo apt-get upgrade -y
sudo apt-get dist-upgrade -y

# Install packages
sudo apt-get install -y docker-ce git vim unattended-upgrades apt-listchanges

# Add user to docker group
if ! groups "$(whoami)" | grep -Fq docker; then
    sudo gpasswd -a "$(whoami)" docker
    RESTART_REQUIRED="true"
fi

# Set timezone 
sudo timedatectl set-timezone "America/Los_Angeles"

# Use CloudFlare DNS servers
if ! grep -qF -- "static domain_name_servers=1.1.1.1 1.0.0.1" /etc/dhcpcd.conf; then
    sudo echo "static domain_name_servers=1.1.1.1 1.0.0.1" >> /etc/dhcpcd.conf
fi

# Configure unattended upgrades
if [ -f /etc/apt/apt.conf.d/50unattended-upgrades ]; then
    # Specify which packages can be updated
    sudo sed -i.bak '/^\s*Unattended-Upgrade::Origins-Pattern [{]\s*$/,/^[}][;]\s*$/c\
Unattended-Upgrade::Origins-Pattern {\
    "origin=Debian,codename=${distro_codename},label=Debian-Security";\
    "origin=Raspbian,codename=${distro_codename},label=Raspbian";\
    "origin=Raspberry Pi Foundation,codename=${distro_codename},label=Raspberry Pi Foundation";\
    "origin=Docker,codename=${distro_codename},label=Docker CE";\
};' /etc/apt/apt.conf.d/50unattended-upgrades
sudo rm /etc/apt/apt.conf.d/50unattended-upgrades.bak

    # Reboot automatically
    sudo sed -i 's/^\/\/Unattended-Upgrade::Automatic-Reboot "false";/Unattended-Upgrade::Automatic-Reboot "true";/g' /etc/apt/apt.conf.d/50unattended-upgrades
    sudo sed -i 's/^\/\/Unattended-Upgrade::Automatic-Reboot-Time "02:00";/Unattended-Upgrade::Automatic-Reboot-Time "02:00";/g' /etc/apt/apt.conf.d/50unattended-upgrades

    # Autoremove dependencies
    sudo sed -i 's/^\/\/Unattended-Upgrade::Remove-Unused-Dependencies "false";/Unattended-Upgrade::Remove-Unused-Dependencies "true";/g' /etc/apt/apt.conf.d/50unattended-upgrades
fi
if [ ! -f /etc/apt/apt.conf.d/20auto-upgrades ]; then
    # Update package lists and packages
sudo tee /etc/apt/apt.conf.d/20auto-upgrades << EOF
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF
fi

# Setup Homebridge
if [ -d "${PIFILES_DIRECTORY}/homebridge" ]; then
    mkdir -p "${HOME}/.homebridge"
    cp -Rf "${PIFILES_DIRECTORY}/homebridge/." "${HOME}/.homebridge"
    for plugin in ${HOME}/.homebridge/*; do
        if [ -d "${plugin}" ]; then
            CONTAINER_NAME="homebridge-$(basename "${plugin}")"
            if [ $(docker ps --filter name="${CONTAINER_NAME}" -q) ]; then
                docker stop "${CONTAINER_NAME}"
                docker rm "${CONTAINER_NAME}"
            fi
            docker pull oznu/homebridge:raspberry-pi
            docker run -d --restart=unless-stopped --net=host --name="${CONTAINER_NAME}" -e PUID=1000 -e PGID=1000 -e TZ=America/Los_Angeles -v ${plugin}/:/homebridge oznu/homebridge:raspberry-pi
        fi
    done
else
    echo "Missing Homebridge configuration. Skipping Homebridge setup."
fi

# Setup DDNS53
if [ -d "${PIFILES_DIRECTORY}/ddns53" ]; then
    mkdir -p "${HOME}/.ddns53"
    cp -Rf "${PIFILES_DIRECTORY}/ddns53/." "${HOME}/.ddns53"
    if [ $(docker ps --filter name=ddns53 -q) ]; then
        docker stop ddns53
        docker rm ddns53
    fi
    docker pull smockle/ddns53:latest
    docker run -d --restart=unless-stopped --name=ddns53 --env-file="${HOME}/.ddns53/config" smockle/ddns53:latest
else
    echo "Missing ddns53 configuration. Skipping ddns53 setup."
fi

if [ -n "${RESTART_REQUIRED}" ]; then
    echo "Pi setup is almost complete. Pi will reboot in 10 seconds to complete setup. Press ^C to cancel reboot."
    sleep 10 && sudo reboot &
fi