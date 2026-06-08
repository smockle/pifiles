# pifiles

Configures Raspberry Pi 4 Model B (ARMv8) running Ubuntu Server 24.04 LTS (64-bit)

# Setup

1. Using [Raspberry Pi Imager](https://www.raspberrypi.org/software/), write Ubuntu Server 24.04 LTS (64-bit) to a USB flash drive (at least 8GB). Before writing, edit OS settings, e.g. hostname, username and password, timezone, and enabling SSH with password auth.

2. Remove the USB flash drive.

3. Insert the USB flash drive in the Raspberry Pi, then connect the Pi to power. After a few moments, the Raspberry Pi should connect to your network and be assigned an IP address. You can find the assigned address (and reserve a static IP address) in the UniFi controller.

4. Connect to the Raspberry Pi via SSH: `ssh ubuntu@YOUR_PI_IP_ADDRESS`. If warned about changed device fingerprint, remove the line with `YOUR_PI_IP_ADDRESS` from `~/.ssh/known_hosts`, then try to connect again.

5. (Optional) First, on the host, create a public + private RSA key pair (e.g. `~/.ssh/id_rsa` & `~/.ssh/id_rsa.pub`): `ssh-keygen -t rsa && chmod 600 ~/.ssh/id_rsa*`, then add a section to `~/.ssh/config` (below). Then, on the Pi, append the contents of the public key to `~/.ssh/authorized_keys`, then prevent further writes: `chmod 444 ~/.ssh/authorized_keys`. Now, you’ll be able to connect to your Raspberry Pi using just `ssh pi`.

   ```Shell
   tee -a ~/.ssh/config << EOF
   Host pi
   HostName YOUR_PI_IP_ADDRESS
   IdentityFile /Users/YOUR_USERNAME/.ssh/id_rsa
   User ubuntu
   EOF
   ```

6. (Optional) Immediately after first login, `apt` operations may fail with `Waiting for cache lock: Could not get lock /var/lib/dpkg/lock-frontend. It is held by process xxxx (unattended-upgr)`. Run `tail -f /var/log/unattended-upgrades/unattended-upgrades-dpkg.log` to follow unattended-upgrades progress.

7. Clone this repository on the Pi, and run relevant lines from `pifiles.sh` to complete setup.
