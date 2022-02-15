# pifiles

Configures Raspberry Pi 4 Model B (ARMv8) running Ubuntu Server 20.04.3 LTS (64-bit)

# Setup

1. Using [Raspberry Pi Imager](https://www.raspberrypi.org/software/), write Ubuntu Server 20.04.3 LTS (64-bit) to a USB flash drive (at least 8GB).

2. If the `system-boot` volume is not mounted, remove and reinsert the USB flash drive.

3. Enable SSH by running `touch /Volumes/system-boot/ssh`.

4. Unmount and remove the USB flash drive.

5. Insert the USB flash drive in the Raspberry Pi, then connect the Pi to power. After a few moments, the Raspberry Pi should connect to your network and be assigned an IP address. You can find the assigned address (and reserve a static IP address) in the UniFi controller or by running `ping 192.168.1.255` (broadcast) then `arp -na | grep -i "dc:a6:32"` ([source](https://ubuntu.com/tutorials/how-to-install-ubuntu-on-your-raspberry-pi#4-boot-ubuntu-server)).

6. Connect to the Raspberry Pi via SSH: `ssh ubuntu@YOUR_PI_IP_ADDRESS`. If warned about changed device fingerprint, remove the line with `YOUR_PI_IP_ADDRESS` from `~/.ssh/known_hosts`, then try to connect again. When prompted for a password, use `ubuntu`. After you log in to the Raspberry Pi, you’ll be prompted to change the password for the default user, if you aren’t, run `passwd`.

7. (Optional) First, on the host, create a public + private RSA key pair (e.g. `~/.ssh/id_rsa` & `~/.ssh/id_rsa.pub`): `ssh-keygen -t rsa && chmod 600 ~/.ssh/id_rsa*`, then add a section to `~/.ssh/config` (below). Then, on the Pi, append the contents of the public key to `~/.ssh/authorized_keys`, then prevent further writes: `chmod 444 ~/.ssh/authorized_keys`. Now, you’ll be able to connect to your Raspberry Pi using just `ssh pi`.

   ```Shell
   tee -a ~/.ssh/config << EOF
   Host pi
   HostName YOUR_PI_IP_ADDRESS
   IdentityFile /Users/YOUR_USERNAME/.ssh/id_rsa
   User ubuntu
   EOF
   ```

8. Clone this repository on the Pi, and run relevant lines from `pifiles.sh` to complete setup.
