# pifiles

Configures Raspberry Pi 3 & 4 (ARMv8) running Raspberry Pi OS Lite

# Setup

1. Download latest Raspberry Pi OS Lite from https://www.raspberrypi.org/software/operating-systems/.

2. Using [Raspberry Pi Imager](https://www.raspberrypi.org/software/), flash the downloaded Raspberry Pi OS image to a Micro SD card (at least 8 GB) and to a USB flash drive.

3. Remove and reinsert the Micro SD card and USB flash drive to mount each `boot` volume.

4. Enable SSH by running `touch /Volumes/boot/ssh` in each volume.

5. Unmount and remove the Micro SD card and USB flash drive.

6. Insert the Micro SD card and USB flash drive in the Raspberry Pi, then connect the Pi to power. After a few moments, the Raspberry Pi should connect to your network and be assigned an IP address. You can find the assigned address (and reserve a static IP address) in the UniFi controller.

7. Connect to the Raspberry Pi (Micro SD card filesystem) via SSH: `ssh pi@YOUR_PI_IP_ADDRESS`. When prompted for a password, use `raspberry`. After you log in to the Raspberry Pi, change the password for the default user: `passwd`.

8. Check existing `PARTUUID`s with `sudo blkid`. If necessary, update the USB flash drive’s `PARTUUID` so that it is unique from the Micro SD card’s `PARTUUID` (kudos [this comment](https://www.raspberrypi.org/forums/viewtopic.php?t=191775#p1203247)):

    ```Shell
    sudo fdisk /dev/sda
    x
    i
    0x77ff00dd
    r
    w
    ```

9. Replace the `PARTUUID` on the Micro USB card’s `/boot/cmdline.txt` with the new `PARTUUID` assigned to the USB flash drive in step 11: `vi /boot/cmdline.txt` (kudos [this comment](https://www.raspberrypi.org/forums/viewtopic.php?t=193157#p1210713))

10. Reboot the Raspberry Pi: `sudo reboot`. Wait a few minutes, then reconnect (USB flash drive filesystem): `ssh pi@YOUR_PI_IP_ADDRESS`. If warned about changed device fingerprint, remove the line with `YOUR_PI_IP_ADDRESS` from `~/.ssh/known_hosts`, then try to connect again.

11. Expand the primary root partition on the USB flash drive (kudos [“Install and run Raspbian from a USB Flash Drive”](https://www.stewright.me/2013/05/install-and-run-raspbian-from-a-usb-flash-drive/)):

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
    # if asked, keep the ext4 signature
    w
    ```

12. Reboot the Raspberry Pi: `sudo reboot`. Wait a few minutes, then reconnect: `ssh pi@YOUR_PI_IP_ADDRESS`.

13. Expand the primary root partition to fill available space: `sudo resize2fs /dev/sda2`.

14. Reboot the Raspberry Pi: `sudo reboot`. Wait a few minutes, then reconnect: `ssh pi@YOUR_PI_IP_ADDRESS`.

15. (Optional) First, on the host, create a public + private RSA key pair (e.g. `~/.ssh/id_rsa` & `~/.ssh/id_rsa.pub`): `ssh-keygen -t rsa && chmod 600 ~/.ssh/id_rsa*`, then add a section to `~/.ssh/config` (below). Then, on the Pi, append the contents of the public key to `~/.ssh/authorized_keys`, then prevent further writes: `chmod 444 ~/.ssh/authorized_keys`. Now, you’ll be able to connect to your Raspberry Pi using just `ssh pi`.

    ```Shell
    tee -a ~/.ssh/config << EOF
    Host pi
    HostName YOUR_PI_IP_ADDRESS
    IdentityFile /Users/YOUR_USERNAME/.ssh/id_rsa
    User pi
    EOF
    ```

16. Clone this repository on the Pi, and run relevant lines from `pifiles.sh` to complete setup.
