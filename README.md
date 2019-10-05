# pifiles

Configures Raspberry Pi 3 & 4 (ARMv8) running Raspbian Buster Lite

# Setup

1. Download latest Raspbian Buster Lite from https://www.raspberrypi.org/downloads/raspbian/

2. Follow the [“Installing operating system images on Mac OS”](https://www.raspberrypi.org/documentation/installation/installing-images/mac.md) instructions to flash the downloaded Raspbian image to a Micro SD card (at least 8 GB)

3. Remove and reinsert the Micro SD card to mount the `boot` volumes

4. Enable SSH: `touch /Volumes/boot/ssh`

5. Unmount and remove the Micro SD card

6. Repeat steps 2–5 with a USB flash drive

7. Insert the Micro SD card and USB flash drive in the Raspberry Pi, then connect the Pi to power. After a few moments, the Raspberry Pi should connect to your network and be assigned an IP address. You can find the assigned address (and reserve a static IP address) in the UniFi controller.

8. Create a public + private RSA key pair (e.g. `~/.ssh/pi.id_rsa` & `~/.ssh/pi.id_rsa.pub`): `ssh-keygen -t rsa && chmod 600 ~/.ssh/pi.id_rsa*`, then store SSH connection information for your Raspberry Pi:

   ```Shell
   tee -a ~/.ssh/config << EOF
   Host pi
   HostName YOUR_PI_IP_ADDRESS
   IdentityFile /Users/YOUR_USERNAME/.ssh/pi.id_rsa
   User pi
   EOF
   ```

9. Connect to the Raspberry Pi via SSH: `ssh pi@YOUR_PI_IP_ADDRESS`. When prompted for a password, use `raspberry`. After you log in to the Raspberry Pi, change the password for the default user: `passwd`

10. Append the contents of the host’s public key to `~/.ssh/authorized_keys`, then prevent further writes: `chmod 444 ~/.ssh/authorized_keys`. Now, you’ll be able to connect to your Raspberry Pi using just `ssh pi`.

11. Check existing `PARTUUID`s with `sudo blkid`. If the USB flash drive so that it is unique from the Micro SD card’s `PARTUUID`:

    ```Shell
    sudo fdisk /dev/sda
    x
    i
    0x77ff00dd
    r
    w
    ```
    
12. Reboot the Raspberry Pi : `sudo reboot`. Wait a few minutes, then reconnect: `ssh raspberrypi`.

13. Expand the primary root partition on the USB flash drive:

    ```Shell
    sudo fdisk /dev/sda
    p # remember where partition 2 starts
    d
    2
    n
    p
    2
    # recall where partition 2 started
    <enter>
    w
    ```

14. Reboot the Raspberry Pi : `sudo reboot`. Wait a few minutes, then reconnect: `ssh raspberrypi`.

15. Replace the `PARTUUID` on the Micro USB card’s `/boot/cmdline.txt` with the new `PARTUUID` assigned to the USB flash drive in step 11: `vi /boot/cmdline.txt`.

16. Reboot the Raspberry Pi : `sudo reboot`. Wait a few minutes, then reconnect: `ssh raspberrypi`.

17. Clone this repository on the Pi, and run `pifiles.sh` to complete setup. Your Pi will reboot.
