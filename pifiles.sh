#!/usr/bin/env bash
set -eo pipefail

# Add Docker repository
if [ ! -f /etc/apt/sources.list.d/docker.list ]; then
    curl -fsSL https://download.docker.com/linux/raspbian/gpg | sudo apt-key add -
    echo "deb [arch=armhf] https://download.docker.com/linux/raspbian buster nightly" | sudo tee /etc/apt/sources.list.d/docker.list
fi

# Update package lists
sudo apt-get update -y
sudo apt-get upgrade -y
sudo apt-get dist-upgrade -y

# Install packages
sudo apt-get install -y git vim unattended-upgrades apt-listchanges zsh
sudo apt-get install -y --no-install-recommends docker-ce

# Set zsh as the default shell
if [ "$SHELL" != "/bin/zsh" ]; then
    sudo chsh -s "/bin/zsh"
    chsh -s "/bin/zsh"
fi

# Add user to docker group
if ! groups "$(whoami)" | grep -Fq docker; then
    sudo gpasswd -a "$(whoami)" docker
    RESTART_REQUIRED="true"
fi

# Set timezone 
sudo timedatectl set-timezone "America/New_York"

# Use CloudFlare DNS servers
if ! grep -qF -- "static domain_name_servers=1.1.1.1 1.0.0.1" /etc/dhcpcd.conf; then
    echo "static domain_name_servers=1.1.1.1 1.0.0.1" | sudo tee -a /etc/dhcpcd.conf
fi

# Configure unattended upgrades
if [ -f /etc/apt/apt.conf.d/50unattended-upgrades ]; then
    # Specify which packages can be updated
    # shellcheck disable=SC1004
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

# Set up Watchtower
if [ "$(docker ps --filter name=watchtower -q)" ]; then
    docker stop watchtower
    docker rm watchtower
fi
docker pull containrrr/watchtower
docker run -d \
    --restart=unless-stopped \
    --name=watchtower \
    -v /var/run/docker.sock:/var/run/docker.sock \
    containrrr/watchtower

# Set up UniFi Controller
if [ -d "${HOME}/.unifi/config" ]; then
    if [ "$(docker ps --filter name=unifi -q)" ]; then
        docker stop unifi
        docker rm unifi
    fi
    docker pull ryansch/unifi-rpi:latest
    docker run --init -d \
        --restart=unless-stopped \
        --net=host \
        --name=unifi \
        -v "${HOME}/.unifi/config":/var/lib/unifi \
        -v "${HOME}/.unifi/log":/usr/lib/unifi/logs \
        -v "${HOME}/.unifi/log2":/var/log/unifi \
        -v "${HOME}/.unifi/run":/usr/lib/unifi/run \
        -v "${HOME}/.unifi/run2":/run/unifi \
        -v "${HOME}/.unifi/work":/usr/lib/unifi/work \
        ryansch/unifi-rpi:latest
else
    echo "Missing UniFi Controller configuration. Skipping UniFi Controller setup."
fi

# Set up SmartGlass
if [ -f "${HOME}/.smartglass/tokens.json" ]; then
    if [ "$(docker ps --filter name=smartglass -q)" ]; then
        docker stop smartglass
        docker rm smartglass
    fi
    docker pull smockle/xbox-smartglass-rest-python
    docker run -d \
        --restart=unless-stopped \
        --name=smartglass \
        -p 5557:5557 \
        -v "${HOME}/.smartglass":/root/.local/share/xbox \
        smockle/xbox-smartglass-rest-python
else
    echo "Missing SmartGlass configuration. Skipping SmartGlass setup."
fi

# Set up Home Assistant
if [ -d "${HOME}/.homeassistant" ]; then
    if [ "$(docker ps --filter name=homeassistant -q)" ]; then
        docker stop homeassistant
        docker rm homeassistant
    fi
    if [[ ! -d "${HOME}/Developer" ]]; then
        mkdir "${HOME}/Developer"
    fi
    if [[ ! -d "${HOME}/Developer/open-zwave" ]]; then
        git clone https://github.com/OpenZWave/open-zwave "${HOME}/Developer/open-zwave"
    fi
    (cd "${HOME}/Developer/open-zwave" && git pull)

    docker pull homeassistant/raspberrypi3-homeassistant
    docker run --init -d \
        --restart=unless-stopped \
        --net=host \
        --name=homeassistant \
        --device=/dev/ttyUSB0 \
        --device=/dev/ttyUSB1 \
        -e PUID=1000 \
        -e PGID=1000 \
        -v /etc/localtime:/etc/localtime:ro \
        -v "${HOME}/.homeassistant":/config \
        -v "${HOME}/Developer/open-zwave/config":/usr/local/lib/python3.7/site-packages/python_openzwave/ozw_config \
        homeassistant/raspberrypi3-homeassistant
else
    echo "Missing Home Assistant configuration. Skipping Home Assistant setup."
fi

# Set up Homebridge
if [ -f "${HOME}/.homebridge/config.json" ]; then
    if [ "$(docker ps --filter name=homebridge -q)" ]; then
        docker stop homebridge
        docker rm homebridge
    fi
    docker pull oznu/homebridge:raspberry-pi
    docker run -d \
        --restart=unless-stopped \
        --net=host \
        --name=homebridge \
        -e PUID=1000 \
        -e PGID=1000 \
        -e TZ=America/New_York \
        -v "${HOME}/.homebridge":/homebridge \
        oznu/homebridge:raspberry-pi
else
    echo "Missing Homebridge configuration. Skipping Homebridge setup."
fi

# Set up DDNS53
if [ -f "${HOME}/.ddns53/env" ]; then
    if [ "$(docker ps --filter name=ddns53 -q)" ]; then
        docker stop ddns53
        docker rm ddns53
    fi
    docker pull smockle/ddns53:latest
    docker run -d \
        --restart=unless-stopped \
        --name=ddns53 \
        --env-file="${HOME}/.ddns53/env" \
        smockle/ddns53:latest
else
    echo "Missing ddns53 configuration. Skipping ddns53 setup."
fi

# Set up strongSwan
if [ -f "${HOME}/.strongswan/env" ]; then
    if [ "$(docker ps --filter name=strongswan -q)" ]; then
        docker stop strongswan
        docker rm strongswan
    fi
    docker pull smockle/alpine-strongswan:latest
    docker run -d \
        --restart=unless-stopped \
        --cap-add=NET_ADMIN \
        --net=host \
        --name=strongswan \
        --env-file="${HOME}/.strongswan/env" \
        -e PUID=1000 \
        -e PGID=1000 \
        -v "${HOME}/.strongswan/config/strongswan.conf":/etc/strongswan.conf \
        -v "${HOME}/.strongswan/config/ipsec.conf":/etc/ipsec.conf \
        -v "${HOME}/.strongswan/config/ipsec.secrets":/etc/ipsec.secrets \
        -v "${HOME}/.strongswan/config/ipsec.d":/etc/ipsec.d \
        smockle/alpine-strongswan
    sudo sed -i -E '/^(#)?( )?net\.ipv4\.ip_forward( )?=( )?[01]/d' /etc/sysctl.conf
    sudo sed -i -E '/^(#)?( )?net\.ipv6\.conf\.all\.forwarding( )?=( )?[01]/d' /etc/sysctl.conf
    sudo sed -i -E '/^(#)?( )?net\.ipv6\.conf\.all\.proxy_ndp( )?=( )?[01]/d' /etc/sysctl.conf
    sudo sed -i -E '/^(#)?( )?net\.ipv6\.conf\.all\.accept_ra( )?=( )?[012]/d' /etc/sysctl.conf
    echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf
    echo "net.ipv6.conf.all.forwarding=1" | sudo tee -a /etc/sysctl.conf
    echo "net.ipv6.conf.all.proxy_ndp=1" | sudo tee -a /etc/sysctl.conf
    echo "net.ipv6.conf.all.accept_ra=2" | sudo tee -a /etc/sysctl.conf
    sudo sysctl -p /etc/sysctl.conf
    sudo iptables -A FORWARD -j ACCEPT
else
    echo "Missing strongSwan configuration. Skipping strongSwan setup."
fi

if [ -n "${RESTART_REQUIRED}" ]; then
    echo "Pi setup is almost complete. Pi will reboot in 10 seconds to complete setup. Press ^C to cancel reboot."
    sleep 10 && sudo reboot &
fi
