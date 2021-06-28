#!/usr/bin/env bash
set -eo pipefail

# Set human-readable hostname
sudo hostnamectl set-hostname "Raspberry Pi" --pretty

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

# Configure `apt`
sudo echo 'APT::Get::Assume-Yes "true";' > /etc/apt/apt.conf.d/90assumeyes

# Update package lists
sudo apt update -y
sudo apt full-upgrade -y
sudo apt dist-upgrade -y

# Install packages
sudo apt install -y vim zsh \
    unifi openjdk-8-jre-headless \
    nodejs gcc g++ make python net-tools \
    git samba hfsplus hfsutils hfsprogs

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

# Set up Homebridge
npm install --global homebridge homebridge-ring homebridge-mi-airpurifier homebridge-roomba2
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

# Add Samba user
sudo smbpasswd -a pi

# Configure Samba
sudo vi /etc/samba/smb.conf

# Restart Samba
sudo systemctl restart smbd

# Disable nmbd (prevents duplicate entries in Finder > Network)
sudo update-rc.d nmbd disable

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
