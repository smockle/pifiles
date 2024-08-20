#!/usr/bin/env bash
set -eo pipefail

# Configure POE+ Hat fan
# Check temperature with `vcgencmd measure_temp`
sudo tee -a /boot/firmware/config.txt << EOF
# Raspberry Pi POE+ Hat fan
dtoverlay=rpi-poe-plus
dtparam=poe_fan_temp0=50000
dtparam=poe_fan_temp1=60000
dtparam=poe_fan_temp2=70000
dtparam=poe_fan_temp3=80000
EOF

# Reboot

# Set timezone 
sudo timedatectl set-timezone "America/New_York"

# Set human-readable hostname
sudo hostnamectl set-hostname "raspberrypi"
sudo hostnamectl set-hostname "Raspberry Pi" --pretty

# Configure `apt`
sudo tee /etc/apt/apt.conf.d/90assumeyes << EOF
APT::Get::Assume-Yes "true";
EOF

# Update packages
sudo apt update
sudo apt full-upgrade
sudo apt autoremove

# Add NodeSource repository
if [ ! -f /etc/apt/sources.list.d/nodesource.list ]; then
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | sudo gpg --dearmor -o /usr/share/keyrings/nodesource.gpg
    echo "deb [arch=arm64 signed-by=/usr/share/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" | sudo tee /etc/apt/sources.list.d/nodesource.list
fi

# Update package lists
sudo apt update
sudo apt full-upgrade
sudo apt autoremove

# Install packages
sudo apt install -y rpi-eeprom zsh \
  nodejs gcc g++ make net-tools

# Set zsh as the default shell
if [ "$SHELL" != "/bin/zsh" ]; then
    sudo chsh -s "/bin/zsh"
    chsh -s "/bin/zsh"
fi

# Link dotfiles

# Change install location for globally-installed NPM modules
mkdir -p ~/.npm-global
npm config set prefix '~/.npm-global'
if ! grep -qF -- "/home/ubuntu/.npm-global/bin" /etc/zsh/zshenv; then
    echo 'export PATH="/home/ubuntu/.npm-global/bin:$PATH"' | sudo tee -a /etc/zsh/zshenv
fi
sudo tee /etc/profile.d/npm-global.sh << EOF
if [ -d "/home/ubuntu/.npm-global" ] ; then
    PATH="/home/ubuntu/.npm-global/bin:$PATH"
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
npm i --location=global npm@latest

# Set up Homebridge
npm install --location=global homebridge homebridge-ring homebridge-mi-airpurifier homebridge-dummy homebridge-levoit-humidifiers homebridge-rachio-irrigation
# homebridge-ring includes https://github.com/homebridge/ffmpeg-for-homebridge
# homebridge-rachio-irrigation requires Webhook Relay
# 1. Install the client: `curl https://my.webhookrelay.com/webhookrelay/downloads/install-cli.sh | bash`
# 2. Log in: `relay login`
# 3. Run as a background service: `sudo relay service install -c /home/ubuntu/.homebridge/Rachio/webhook-relay.yaml --user ubuntu && sudo relay service start`

sudo tee /etc/systemd/system/homebridge@.service << EOF
[Unit]
Description=Homebridge %I
Wants=network-online.target
After=syslog.target network-online.target

[Service]
Type=simple
User=ubuntu
ExecStart=/home/ubuntu/.npm-global/bin/homebridge -D -U /home/ubuntu/.homebridge/%I
SyslogIdentifier=homebridge-%I
Restart=on-failure
RestartSec=10
KillMode=process

[Install]
WantedBy=multi-user.target
EOF

# Copy `~/.homebridge/*`

sudo systemctl daemon-reload
sudo systemctl enable homebridge@Dummy
sudo systemctl enable homebridge@Levoit
sudo systemctl enable homebridge@Rachio
sudo systemctl enable homebridge@Ring
sudo systemctl enable homebridge@Xiaomi
sudo systemctl start homebridge@Dummy
sudo systemctl start homebridge@Levoit
sudo systemctl start homebridge@Rachio
sudo systemctl start homebridge@Ring
sudo systemctl start homebridge@Xiaomi

# Reboot
