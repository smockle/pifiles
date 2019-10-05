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
    git pkg-config autoconf automake libtool libx264-dev

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
random_mac() {
    # https://superuser.com/a/218650/257969
    printf '02:%02X:%02X:%02X:%02X:%02X\n' $[RANDOM%256] $[RANDOM%256] $[RANDOM%256] $[RANDOM%256] $[RANDOM%256]
}
random_pin() {
    printf '%03d-%02d-%03d\n' $[RANDOM%1000] $[RANDOM%100] $[RANDOM%1000]
}

npm i -g homebridge homebridge-ring homebridge-smartthings-tonesto7 homebridge-roomba-stv homebridge-harmony-tv-smockle

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

mkdir -p ~/.homebridge/Ring
if [ ! -f ~/.homebridge/Ring/config.json ]; then
    echo "Run \"npx -p ring-client-api ring-auth-cli\" to obtain a refresh token."
    read -p "Refresh token: " RING_REFRESH_TOKEN
tee ~/.homebridge/Ring/config.json << EOF
{
  "bridge": {
    "name": "Homebridge Ring",
    "username": "$(random_mac)",
    "port": 51826,
    "pin": "$(random_pin)"
  },
  "description": "Homebridge Ring",
  "accessories": [],
  "platforms": [{
    "platform": "Ring",
    "refreshToken": "${RING_REFRESH_TOKEN}",
    "hideCameraSirenSwitch": true,
    "hideAlarmSirenSwitch": true,
    "hideDoorbellSwitch": true
  }]
}
EOF
    unset RING_REFRESH_TOKEN
fi

mkdir -p ~/.homebridge/SmartThings
if [ ! -f ~/.homebridge/SmartThings/config.json ]; then
    read -p "App URL: " SMARTTHINGS_APP_URL
    read -p "App ID: " SMARTTHINGS_APP_ID
    read -p "Access token: " SMARTTHINGS_ACCESS_TOKEN
tee ~/.homebridge/SmartThings/config.json << EOF
{
  "bridge": {
    "name": "Homebridge SmartThings",
    "username": "$(random_mac)",
    "port": 51827,
    "pin": "$(random_pin)"
  },
  "description": "Homebridge SmartThings",
  "accessories": [],
  "platforms": [{
    "platform": "SmartThings",
    "name": "SmartThings",
    "app_url": "${SMARTTHINGS_APP_URL}",
    "app_id": "${SMARTTHINGS_APP_ID}",
    "access_token": "${SMARTTHINGS_ACCESS_TOKEN}",
    "update_method": "direct"
  }]
}
EOF
    unset SMARTTHINGS_APP_URL
    unset SMARTTHINGS_APP_ID
    unset SMARTTHINGS_ACCESS_TOKEN
fi

mkdir -p ~/.homebridge/Roomba
if [ ! -f ~/.homebridge/Roomba/config.json ]; then
    read -p "Roomba IP address: " ROOMBA_IP_ADDRESS
    echo "Run \"cd $(npm root -g)/homebridge-roomba-stv && npm run getrobotpwd ${ROOMBA_IP_ADDRESS}\" to obtain BLID and password."
    read -p "Roomba BLID: " ROOMBA_BLID
    read -p "Roomba Password: " ROOMBA_PASSWORD
tee ~/.homebridge/Roomba/config.json << EOF
{
  "bridge": {
    "name": "Homebridge Roomba",
    "username": "$(random_mac)",
    "port": 51828,
    "pin": "$(random_pin)"
  },
  "description": "Homebridge Roomba",
  "accessories": [{
    "accessory": "Roomba",
    "name": "Roomba",
    "model": "960",
    "blid": "${ROOMBA_BLID}",
    "robotpwd": "${ROOMBA_PASSWORD}",
    "ipaddress": "${ROOMBA_IP_ADDRESS}",
    "refreshMode": "keepAlive",
    "pollingInterval": 30,
    "cacheTTL": 30
  }],
  "platforms": []
}
EOF
    unset ROOMBA_IP_ADDRESS
    unset ROOMBA_BLID
    unset ROOMBA_PASSWORD
fi

mkdir -p ~/.homebridge/HarmonyHub
if [ ! -f ~/.homebridge/HarmonyHub/config.json ]; then
    read -p "Harmony IP address: " HARMONY_IP_ADDRESS
    echo "Run \"cd $(npm root -g)/homebridge-harmony-tv-smockle/script/hubinfo.js ${HARMONY_IP_ADDRESS}\" to obtain device id."
    read -p "Harmony device id: " HARMONY_DEVICE_ID
    read -p "Harmony device name: " HARMONY_DEVICE_NAME
tee ~/.homebridge/HarmonyHub/config.json << EOF
{
  "bridge": {
    "name": "Homebridge HarmonyHub",
    "username": "$(random_mac)",
    "port": 51829,
    "pin": "$(random_pin)"
  },
  "description": "Homebridge HarmonyHub",
  "accessories": [{
    "accessory": "HarmonyTV",
    "name": "${HARMONY_DEVICE_NAME}",
    "host": "${HARMONY_IP_ADDRESS}",
    "deviceId": "${HARMONY_DEVICE_ID}",
    "commands": [{
      "action": "{\"command\":\"PowerToggle\",\"type\":\"IRCommand\",\"deviceId\":\"${HARMONY_DEVICE_ID}\"}",
      "name": "PowerToggle",
      "label": "Power Toggle"
    }, {
      "action": "{\"command\":\"VolumeDown\",\"type\":\"IRCommand\",\"deviceId\":\"${HARMONY_DEVICE_ID}\"}",
      "name": "VolumeDown",
      "label": "Volume Down"
    }, {
      "action": "{\"command\":\"VolumeUp\",\"type\":\"IRCommand\",\"deviceId\":\"${HARMONY_DEVICE_ID}\"}",
      "name": "VolumeUp",
      "label": "Volume Up"
    }, {
      "action": "{\"command\":\"DirectionDown\",\"type\":\"IRCommand\",\"deviceId\":\"${HARMONY_DEVICE_ID}\"}",
      "name": "DirectionDown",
      "label": "Direction Down"
    }, {
      "action": "{\"command\":\"DirectionLeft\",\"type\":\"IRCommand\",\"deviceId\":\"${HARMONY_DEVICE_ID}\"}",
      "name": "DirectionLeft",
      "label": "Direction Left"
    }, {
      "action": "{\"command\":\"DirectionRight\",\"type\":\"IRCommand\",\"deviceId\":\"${HARMONY_DEVICE_ID}\"}",
      "name": "DirectionRight",
      "label": "Direction Right"
    }, {
      "action": "{\"command\":\"DirectionUp\",\"type\":\"IRCommand\",\"deviceId\":\"${HARMONY_DEVICE_ID}\"}",
      "name": "DirectionUp",
      "label": "Direction Up"
    }, {
      "action": "{\"command\":\"Select\",\"type\":\"IRCommand\",\"deviceId\":\"${HARMONY_DEVICE_ID}\"}",
      "name": "Select",
      "label": "Select"
    }, {
      "action": "{\"command\":\"Menu\",\"type\":\"IRCommand\",\"deviceId\":\"${HARMONY_DEVICE_ID}\"}",
      "name": "Menu",
      "label": "Menu"
    }, {
      "action": "{\"command\":\"InputHdmi1\",\"type\":\"IRCommand\",\"deviceId\":\"${HARMONY_DEVICE_ID}\"}",
      "name": "InputHdmi1",
      "label": "InputHdmi1"
    }, {
      "action": "{\"command\":\"InputHdmi2\",\"type\":\"IRCommand\",\"deviceId\":\"${HARMONY_DEVICE_ID}\"}",
      "name": "InputHdmi2",
      "label": "InputHdmi2"
    }]
  }],
  "platforms": []
}
EOF
    unset HARMONY_IP_ADDRESS
    unset HARMONY_DEVICE_ID
    unset HARMONY_DEVICE_NAME
fi

sudo systemctl daemon-reload
sudo systemctl enable homebridge@Ring
sudo systemctl enable homebridge@SmartThings
sudo systemctl enable homebridge@Roomba
sudo systemctl enable homebridge@HarmonyHub
sudo systemctl start homebridge@Ring
sudo systemctl start homebridge@SmartThings
sudo systemctl start homebridge@Roomba
sudo systemctl start homebridge@HarmonyHub

unset random_mac
unset random_pin

# Set up Home Assistant
mkdir -p ~/.venv
cd ~/.venv
if [ -d homeassistant ]; then
  python3 -m venv --upgrade homeassistant
else
  python3 -m venv homeassistant
fi
cd homeassistant
source bin/activate
if systemctl is-active --quiet homeassistant.service; then
  sudo systemctl stop homeassistant
  python3 -m pip install --upgrade homeassistant
  sudo systemctl start homeassistant
else
  python3 -m pip install homeassistant
fi
cd ~

sudo tee /etc/systemd/system/homeassistant.service << EOF
[Unit]
Description=Home Assistant
Wants=network-online.target
After=syslog.target network-online.target

[Service]
Type=simple
User=pi
ExecStart=/home/pi/.venv/homeassistant/bin/hass -c "/home/pi/.homeassistant"
Restart=on-failure
RestartSec=10
KillMode=process

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable homeassistant
sudo systemctl start homeassistant

# Set up DDNS53
pip3 install --upgrade awscli

if [ ! -f /home/pi/.ddns53/env ]; then
    read -p "Hosted Zone ID: " DDNS53_HOSTED_ZONE_ID
    read -p "Domain: " DDNS53_DOMAIN
    read -p "AWS Access Key ID: " AWS_ACCESS_KEY_ID
    read -p "AWS Secret Access Key: " AWS_SECRET_ACCESS_KEY
tee /home/pi/.ddns53/env << EOF
HOSTED_ZONE_ID=${DDNS53_HOSTED_ZONE_ID}
DOMAIN=${DDNS53_DOMAIN}
AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
EOF
    unset DDNS53_HOSTED_ZONE_ID
    unset DDNS53_DOMAIN
    unset AWS_ACCESS_KEY_ID
    unset AWS_SECRET_ACCESS_KEY
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
ExecStart=/home/pi/Developer/pifiles/ddns53.sh
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
sudo systemctl enable ddns53.timer
sudo systemctl start ddns53.timer
