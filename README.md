# pifiles

Configures Raspberry Pi 2 (ARMv7) & 3 (ARMv8) running Raspbian Stretch Lite

# Setup

1. Download latest Raspbian Stretch Lite from https://www.raspberrypi.org/downloads/raspbian/

2. Install Etcher, a utility for flashing SD cards: `brew cask install balenaetcher`. Use Etcher to flash the downloaded Raspbian image to a Micro SD card (at least 8 GB)

3. Remove and reinsert the Micro SD card to mount the `boot` volume

4. Enable SSH: `touch /Volumes/boot/ssh`

5. Enable Wi-Fi:

   ```Bash
   tee /Volumes/boot/wpa_supplicant.conf << EOF
   ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
   update_config=1
   country=US

   network={
   ssid="YOUR_WIFI_SSID"
   psk="YOUR_WIFI_PASSWORD"
   key_mgmt=WPA-PSK
   }
   EOF
   ```

6. Unmount and remove the Micro SD card, insert it in the Raspberry Pi, then connect the Pi to power. After a few moments, the Raspberry Pi should connect to your Wi-Fi network and be assigned an IP address. You can find the assigned address (and reserve a static IP address) using the AirPort utility.

7. Create a public + private RSA key pair (e.g. `~/.ssh/id_rsa` & `~/.ssh/id_rsa.pub`): `ssh-keygen -t rsa`, then store SSH connection information for your Raspberry Pi:

   ```Bash
   tee -a ~/.ssh/config << EOF
   Host pi
   HostName YOUR_PI_IP_ADDRESS
   IdentityFile /Users/YOUR_USERNAME/.ssh/id_rsa
   User pi
   EOF
   ```

8. Connect to the Raspberry Pi via SSH: `ssh pi@YOUR_PI_IP_ADDRESS`. When prompted for a password, use `raspberry`. After you log in to the Raspberry Pi, change the password for the default user: `passwd`

9. Append the contents of the host’s public key to `~/.ssh/authorized_keys`, then prevent further writes: `chmod 444 ~/.ssh/authorized_keys`. Now, you’ll be able to connect to your Raspberry Pi using just `ssh pi`.

10. Clone this repository on the Pi, and run `pifiles.sh` to complete setup. Your Pi will reboot.

# Running applications

`pifiles.sh` will run [ddns53](https://github.com/smockle/ddns53) & [homebridge](https://github.com/oznu/docker-homebridge) if configuration files are present. To start these applications:

1. Run `copyto.sh pi` in a working directory that contains your configuration files to copy them to the Pi.

2. Connect to the Pi via SSH, and re-run `pifiles.sh`.
