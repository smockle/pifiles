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

---

## 🥧 Easter Egg: Classic Apple Pie Recipe

Since you're here for *pi*files, here's a delicious **pie** recipe to enjoy while your Raspberry Pi sets itself up!

### Ingredients

**For the crust:**
- 2½ cups all-purpose flour
- 1 tsp salt
- 1 tsp sugar
- 1 cup (2 sticks) unsalted butter, cold and cubed
- ¼ to ½ cup ice water

**For the filling:**
- 6-7 large apples (Granny Smith or Honeycrisp), peeled and sliced
- ¾ cup granulated sugar
- ¼ cup brown sugar
- 2 tbsp all-purpose flour
- 1 tsp ground cinnamon
- ¼ tsp ground nutmeg
- 1 tbsp lemon juice
- 2 tbsp butter, cut into small pieces

**For assembly:**
- 1 egg, beaten (for egg wash)
- 1 tbsp coarse sugar (optional)

### Instructions

1. **Make the crust:** In a large bowl, mix flour, salt, and sugar. Cut in cold butter until mixture resembles coarse crumbs. Gradually add ice water until dough comes together. Divide in half, form into disks, wrap in plastic, and refrigerate for at least 1 hour.

2. **Prepare the filling:** In a large bowl, toss sliced apples with sugars, flour, cinnamon, nutmeg, and lemon juice. Let sit for 15 minutes.

3. **Assemble:** Preheat oven to 375°F (190°C). Roll out one disk of dough and fit into a 9-inch pie pan. Add apple filling and dot with butter pieces. Roll out second disk and place over filling. Trim, seal, and crimp edges. Cut slits in top crust for ventilation.

4. **Bake:** Brush top with egg wash and sprinkle with coarse sugar if desired. Bake for 50-60 minutes until crust is golden and filling is bubbly. Cover edges with foil if browning too quickly.

5. **Cool:** Let cool for at least 2 hours before slicing. Serve with vanilla ice cream!

*Estimated baking time: About the same as running `apt update && apt upgrade` on a fresh Pi installation.* 😄
