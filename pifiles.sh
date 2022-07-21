#!/usr/bin/env bash
set -eo pipefail

# Configure POE+ Hat fan
# Check temperature with `vcgencmd measure_temp`
sudo tee -a /boot/firmware/usercfg.txt << EOF
# Raspberry Pi POE+ Hat fan
dtoverlay=rpi-poe
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

# Install pre-requisites
# Ref: https://help.ui.com/hc/en-us/articles/220066768-UniFi-Network-How-to-Install-and-Update-via-APT-on-Debian-or-Ubuntu
sudo apt install -y apt-transport-https
sudo apt-mark hold openjdk-11-*

# Add Ubiquiti repository
# Ref: https://gist.github.com/jasco/2d39fdc808a1c482ed3c295d0e09c116#configure-apt-unifi-for-arm64
if [ ! -f /etc/apt/sources.list.d/ubiquiti.list ]; then
    curl -fsSL https://dl.ui.com/unifi/unifi-repo.gpg | sudo apt-key add -
    echo "deb [arch=armhf] https://www.ui.com/downloads/unifi/debian stable ubiquiti" | sudo tee /etc/apt/sources.list.d/ubiquiti.list
fi

# Add NodeSource repository
if [ ! -f /etc/apt/sources.list.d/nodesource.list ]; then
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource.gpg.key | sudo apt-key add -
    echo "deb https://deb.nodesource.com/node_16.x focal main" | sudo tee /etc/apt/sources.list.d/nodesource.list
fi

# Update package lists
sudo apt update
sudo apt full-upgrade
sudo apt autoremove

# Install packages
sudo apt install -y rpi-eeprom zsh \
  unifi openjdk-8-jre-headless \
  nodejs gcc g++ make net-tools \
  samba avahi-daemon

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
npm install --location=global homebridge homebridge-ring homebridge-mi-airpurifier homebridge-dummy git+https://git@github.com/pschroeder89/homebridge-levoit-humidifiers.git#v1.7.1
# homebridge-ring includes https://github.com/homebridge/ffmpeg-for-homebridge

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
sudo systemctl enable homebridge@Ring
sudo systemctl enable homebridge@Xiaomi
sudo systemctl start homebridge@Dummy
sudo systemctl start homebridge@Ring
sudo systemctl start homebridge@Xiaomi

# Add Samba user
sudo smbpasswd -a ubuntu

# Configure Samba
sudo vi /etc/samba/smb.conf

# Restart Samba
sudo systemctl restart smbd

# Disable nmbd (prevents duplicate entries in Finder > Network)
sudo systemctl stop nmbd.service
sudo systemctl disable nmbd.service

# Advertise services over Bonjour
# https://kremalicious.com/raspberry-pi-file-and-screen-sharing-macos-ios

# Advertise Samba
# (Use Avahi instead of the built-in advertiser to support pretty computer names.)
sudo tee /etc/avahi/services/smb.service << EOF
<?xml version="1.0" standalone='no'?>
<!DOCTYPE service-group SYSTEM "avahi-service.dtd">
<service-group>
  <name replace-wildcards="yes">Raspberry Pi</name>
  <service>
    <type>_smb._tcp</type>
    <port>445</port>
  </service>
  <service>
    <type>_device-info._tcp</type>
    <port>0</port>
    <txt-record>model=TimeCapsule6,116</txt-record>
  </service>
</service-group>
EOF

# Advertise SFTP
sudo tee /etc/avahi/services/sftp.service << EOF
<?xml version="1.0" standalone='no'?>
 <!DOCTYPE service-group SYSTEM "avahi-service.dtd">
 <service-group>
   <name replace-wildcards="yes">Raspberry Pi</name>
   <service>
     <type>_sftp-ssh._tcp</type>
     <port>22</port>
   </service>
</service-group>
EOF

# Advertise SSH
sudo tee /etc/avahi/services/ssh.service << EOF
<?xml version="1.0" standalone='no'?>
 <!DOCTYPE service-group SYSTEM "avahi-service.dtd">
 <service-group>
   <name replace-wildcards="yes">Raspberry Pi</name>
   <service>
     <type>_ssh._tcp</type>
     <port>22</port>
   </service>
</service-group>
EOF

sudo service avahi-daemon restart

# Make syslog readable
sudo chmod +r /var/log/syslog

# Restore Unifi backup

# Reboot