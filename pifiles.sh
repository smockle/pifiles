#!/usr/bin/env bash
set -eo pipefail

# Add Ubiquiti repository
if [ ! -f /etc/apt/sources.list.d/ubiquiti.list ]; then
    curl -fsSL https://dl.ui.com/unifi/unifi-repo.gpg | sudo apt-key add -
    echo "deb https://www.ui.com/downloads/unifi/debian stable ubiquiti" | sudo tee /etc/apt/sources.list.d/ubiquiti.list
fi

# Add NodeSource repository
if [ ! -f /etc/apt/sources.list.d/nodesource.list ]; then
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource.gpg.key | sudo apt-key add -
    echo "deb https://deb.nodesource.com/node_10.x buster main" | sudo tee /etc/apt/sources.list.d/nodesource.list
fi

# Update package lists
sudo apt-get update -y
sudo apt-get upgrade -y
sudo apt-get dist-upgrade -y

# Install packages
sudo apt-get install -y zsh vim \
    unattended-upgrades apt-listchanges \
    unifi openjdk-8-jre-headless haveged \
    nodejs libavahi-compat-libdnssd-dev \
    python3 python3-pip dnsutils \
    git pkg-config autoconf automake libtool libx264-dev \
    shairport-sync

# Change install location for globally-installed NPM modules
mkdir ~/.npm-global
npm config set prefix '~/.npm-global'
sudo tee /etc/profile.d/npm-global.sh << EOF
if [ -d "/home/pi/.npm-global" ] ; then
    PATH="/home/pi/.npm-global/bin:$PATH"
fi
EOF
sudo chmod +x /etc/profile.d/npm-global.sh
source /etc/profile

# Update NPM
npm i -g npm@latest

# Set zsh as the default shell
if [ "$SHELL" != "/bin/zsh" ]; then
    sudo chsh -s "/bin/zsh"
    chsh -s "/bin/zsh"
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
    "origin=Ubiquiti Networks, Inc.,codename=stable,label=Ubiquiti Networks, Inc.";\
    "origin=Node Source,codename=${distro_codename},label=Node Source";\
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

# Set up ffmpeg
if ! which -a ffmpeg &>/dev/null; then
    if [ ! -d /home/pi/Developer/fdk-aac ]; then
        git clone https://github.com/mstorsjo/fdk-aac.git /home/pi/Developer/fdk-aac
    fi
    cd /home/pi/Developer/fdk-aac
    ./autogen.sh
    ./configure --prefix=/usr/local --enable-shared --enable-static
    make -j4
    sudo make install
    sudo ldconfig

    if [ ! -d /home/pi/Developer/ffmpeg ]; then
        git clone https://github.com/FFmpeg/FFmpeg.git /home/pi/Developer/ffmpeg
    fi
    cd /home/pi/Developer/ffmpeg
    ./configure --prefix=/usr/local --arch=armel --target-os=linux --enable-omx-rpi --enable-nonfree --enable-gpl --enable-libfdk-aac --enable-mmal --enable-libx264 --enable-decoder=h264 --enable-network --enable-protocol=tcp --enable-demuxer=rtsp
    make -j4
    sudo make install
    cd /home/pi/Developer/pifiles
fi

# Set up Homebridge
npm i -g homebridge

sudo tee /etc/default/homebridge << EOF
# The following settings tells homebridge where to find the config.json file
# and where to persist the data
HOMEBRIDGE_OPTS=-D -U /home/pi/.homebridge

# If you uncomment the following line, homebridge will log more
# DEBUG=*
# You can display logs via systemd's journalctl: journalctl -fu homebridge
EOF

sudo tee /etc/systemd/system/homebridge.service << EOF
[Unit]
Description=Homebridge
Wants=network-online.target
After=syslog.target network-online.target

[Service]
Type=simple
User=pi
EnvironmentFile=/etc/default/homebridge
ExecStart=/home/pi/.npm-global/bin/homebridge \$HOMEBRIDGE_OPTS
Restart=on-failure
RestartSec=10
KillMode=process

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable homebridge
sudo systemctl start homebridge

# Set up DDNS53
if [ ! -d /home/pi/Developer/ddns53 ]; then
    git clone https://github.com/smockle/ddns53 /home/pi/Developer/ddns53
fi

pip3 install --upgrade awscli

if [ ! -f /home/pi/.ddns53/env ]; then
tee /home/pi/.ddns53/env << EOF
HOSTED_ZONE_ID=
DOMAIN=
AWS_ACCESS_KEY_ID=
AWS_SECRET_ACCESS_KEY=
EOF
fi

sudo tee /etc/systemd/system/ddns53.service << EOF
[Unit]
Description=Periodically update an A record
Wants=network-online.target
After=syslog.target network-online.target

[Service]
Type=oneshot
User=pi
EnvironmentFile=/home/pi/.ddns53/env
ExecStart=/home/pi/Developer/ddns53/ddns53.sh
EOF

sudo tee /etc/systemd/system/ddns53.timer << EOF
[Unit]
Description=Periodically update an A record

[Timer]
OnBootSec=15min
OnUnitActiveSec=15min

[Install]
WantedBy=timers.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable ddns53
sudo systemctl start ddns53
