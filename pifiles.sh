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
    echo "deb https://deb.nodesource.com/node_16.x buster main" | sudo tee /etc/apt/sources.list.d/nodesource.list
fi

# Update package lists
sudo apt update -y
sudo apt full-upgrade -y
sudo apt dist-upgrade -y

# Install packages
sudo apt install -y zsh \
    unifi openjdk-8-jre-headless \
    nodejs gcc g++ make python net-tools \
    git

# Change install location for globally-installed NPM modules
mkdir -p ~/.npm-global
npm config set prefix '~/.npm-global'
if ! grep -qF -- "/home/pi/.npm-global/bin" /etc/zsh/zshenv; then
    echo 'export PATH="/home/pi/.npm-global/bin:$PATH"' | sudo tee -a /etc/zsh/zshenv
fi
sudo tee /etc/profile.d/npm-global.sh << EOF
if [ -d "/home/pi/.npm-global" ] ; then
    PATH="/home/pi/.npm-global/bin:$PATH"
fi
EOF
sudo chmod +x /etc/profile.d/npm-global.sh
if [[ "${SHELL}" == */bash ]]; then
    source /etc/profile
fi
if [[ "${SHELL}" == */zsh ]]; then
    source /etc/zsh/zshenv
fi

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

# Set up Homebridge
npm install --global homebridge homebridge-ring homebridge-mi-airpurifier homebridge-roomba-stv
# homebridge-ring includes https://github.com/homebridge/ffmpeg-for-homebridge

sudo tee /etc/systemd/system/homebridge@.service << EOF
[Unit]
Description=Homebridge %I
Wants=network-online.target
After=syslog.target network-online.target

[Service]
Type=simple
User=pi
ExecStart=/home/pi/.npm-global/bin/homebridge -D -U /home/pi/.homebridge/%I
SyslogIdentifier=homebridge-%I
Restart=on-failure
RestartSec=10
KillMode=process

[Install]
WantedBy=multi-user.target
EOF

# Copy `~/.homebridge/*`

sudo systemctl daemon-reload
sudo systemctl enable homebridge@Ring
sudo systemctl enable homebridge@Roomba
sudo systemctl enable homebridge@Xiaomi
sudo systemctl start homebridge@Ring
sudo systemctl start homebridge@Roomba
sudo systemctl start homebridge@Xiaomi

# Restore Unifi backup
