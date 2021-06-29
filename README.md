# pifiles

Configures Raspberry Pi 4 Model B (ARMv8) running Raspberry Pi OS Lite

# Setup

1. Download latest Raspberry Pi OS Lite from https://www.raspberrypi.org/software/operating-systems/.

2. Using [Raspberry Pi Imager](https://www.raspberrypi.org/software/), flash the downloaded Raspberry Pi OS image to a USB flash drive (at least 8GB).

3. Remove and reinsert the USB flash drive to mount the `boot` volume.

4. Enable SSH by running `touch /Volumes/boot/ssh`.

5. Unmount and remove the USB flash drive.

6. Insert the USB flash drive in the Raspberry Pi, then connect the Pi to power. After a few moments, the Raspberry Pi should connect to your network and be assigned an IP address. You can find the assigned address (and reserve a static IP address) in the UniFi controller or by running `ping 192.168.1.255` (broadcast) then `arp -a`.

7. Connect to the Raspberry Pi via SSH: `ssh pi@YOUR_PI_IP_ADDRESS`. If warned about changed device fingerprint, remove the line with `YOUR_PI_IP_ADDRESS` from `~/.ssh/known_hosts`, then try to connect again. When prompted for a password, use `raspberry`. After you log in to the Raspberry Pi, change the password for the default user: `passwd`.

8. Expand the primary root partition on the USB flash drive (kudos [“Install and run Raspbian from a USB Flash Drive”](https://www.stewright.me/2013/05/install-and-run-raspbian-from-a-usb-flash-drive/)):

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
    # if asked, do not remove the ext4 signature
    w
    ```

9. Reboot the Raspberry Pi: `sudo reboot`. Wait a few minutes, then reconnect: `ssh pi@YOUR_PI_IP_ADDRESS`.

10. Expand the primary root partition to fill available space: `sudo resize2fs /dev/sda2`.

11. Reboot the Raspberry Pi: `sudo reboot`. Wait a few minutes, then reconnect: `ssh pi@YOUR_PI_IP_ADDRESS`. Verify the partition and filesystem are sized as expected with `sudo fdisk -l` and `df -h`.

12. (Optional) First, on the host, create a public + private RSA key pair (e.g. `~/.ssh/id_rsa` & `~/.ssh/id_rsa.pub`): `ssh-keygen -t rsa && chmod 600 ~/.ssh/id_rsa*`, then add a section to `~/.ssh/config` (below). Then, on the Pi, append the contents of the public key to `~/.ssh/authorized_keys`, then prevent further writes: `chmod 444 ~/.ssh/authorized_keys`. Now, you’ll be able to connect to your Raspberry Pi using just `ssh pi`.

    ```Shell
    tee -a ~/.ssh/config << EOF
    Host pi
    HostName YOUR_PI_IP_ADDRESS
    IdentityFile /Users/YOUR_USERNAME/.ssh/id_rsa
    User pi
    EOF
    ```

13. Clone this repository on the Pi, and run relevant lines from `pifiles.sh` to complete setup.
