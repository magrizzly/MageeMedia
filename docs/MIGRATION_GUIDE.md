# Step-by-Step Windows 10 to Ubuntu 24.04 Migration Guide

This guide walks through the zero-data-loss migration from the existing Windows 10 installation onto the **1 TB Innodisk SSD**, **3× 14 TB Toshiba (`MG07ACA14TE`)** MergerFS + SnapRAID pool, and **3 TB + 4 TB Btrfs RAID 1 Vault**.

---

## Phase 1: Pre-Flight Steps on Windows 10 (Before Powering Down)

1. **Disable Windows Hibernation / Fast Startup:**
   Open PowerShell as Administrator and run:
   ```powershell
   powercfg /h off
   ```
   *Why:* This removes `C:\hiberfil.sys` and ensures Windows does not leave the `C:`, `D:`, and `E:` NTFS filesystems in a locked/hibernated state when you boot into Ubuntu.

2. **Disable "Auto Empty Trash" in Plex:**
   * Open Plex Web (`http://127.0.0.1:32400/web`) → **Settings** → **Library**.
   * **Uncheck** *"Empty trash automatically after every scan"* and click **Save Changes**.
   * *Why:* Prevents Plex from deleting library entries or watch history while transitioning library paths from `D:\Media\...` to `/data/media/...`.

3. **Run the Config Export Script:**
   From this repository, run:
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\scripts\export-windows-configs.ps1
   ```
   This script automatically creates `E:\Migration_Backup` containing:
   * A ready-to-use Linux `Preferences.xml` generated directly from your Windows Registry (`HKCU:\Software\Plex, Inc.\Plex Media Server`).
   * Your Tautulli database (`tautulli.db`) and a Linux-updated `config.ini`.
   * Your Pi-hole v6 (`/etc/pihole`, `/etc/dnsmasq.d`) and Unbound (`pi-hole.conf`) files extracted from WSL1.

---

## Phase 2: Physical Drive Installation & Ubuntu 24.04 LTS Install

1. **Connect the Drives:**
   * Plug the **6 permanent drives** into the **6 native Intel Z87 SATA ports (`SATA6G_1` to `SATA6G_6`)**:
     * `SATA6G_1`: 1 TB Innodisk SSD (`DES25-01TDK1KCCQL`)
     * `SATA6G_2`: 14 TB Toshiba #1 (`MG07ACA14TE`)
     * `SATA6G_3`: 14 TB Toshiba #2 (`MG07ACA14TE`)
     * `SATA6G_4`: 14 TB Toshiba #3 (`MG07ACA14TE`)
     * `SATA6G_5`: 3 TB WD Blue (`WD30EZRZ` — currently `D:`)
     * `SATA6G_6`: 4 TB Seagate (`ST4000DM004` — currently `E:`)
   * Plug the old **64 GB SanDisk SSD** (Windows `C:`) into the top ASMedia SATA port (`SATA6G_E1`) — *or leave it unplugged during the 10-minute Ubuntu install so the installer only targets the 1 TB Innodisk SSD*.

2. **Install Ubuntu Server 24.04 LTS:**
   * Select **Use an entire disk** on the **1 TB Innodisk SSD (`DES25-01TDK1KCCQL`)** (*uncheck "Set up this disk as an LVM group" so it uses the full 1 TB immediately without holding space back in a volume group*).
   * Enable **Install OpenSSH server**.

3. **Run the Host Bootstrap Script:**
   After booting into Ubuntu:
   ```bash
   git clone https://github.com/magrizzly/MageeMedia.git ~/MageeMedia
   cd ~/MageeMedia
   sudo bash scripts/setup-ubuntu-host.sh
   ```

---

## Phase 3: Format the 3× 14 TB Drives & Evacuate the Old 3 TB / 4 TB Drives

> [!IMPORTANT]
> Because your existing ~4.0 TB of media and photos currently sit on the **3 TB (`D:`)** and **4 TB (`E:`)** NTFS drives, you must copy that data onto the new **28 TB MergerFS pool** and **1 TB SSD** *before* formatting the 3 TB and 4 TB drives as Btrfs RAID 1!

1. **Identify the 3× 14 TB Toshiba Drives:**
   ```bash
   lsblk -o NAME,MODEL,SERIAL,SIZE,FSTYPE,MOUNTPOINT
   ```
   Partition and format each of the three 14 TB drives (`sdX`, `sdY`, `sdZ`):
   ```bash
   # On Data Disk 1 & Data Disk 2 (-m 0 reclaims 5% reserved space = ~700 GB per drive; -T largefile4 optimizes for media):
   sudo parted -s /dev/sdX mklabel gpt mkpart primary ext4 0% 100%
   sudo mkfs.ext4 -m 0 -T largefile4 -L disk1 /dev/sdX1

   sudo parted -s /dev/sdY mklabel gpt mkpart primary ext4 0% 100%
   sudo mkfs.ext4 -m 0 -T largefile4 -L disk2 /dev/sdY1

   # On SnapRAID Parity Disk (-m 0 -T largefile4):
   sudo parted -s /dev/sdZ mklabel gpt mkpart primary ext4 0% 100%
   sudo mkfs.ext4 -m 0 -T largefile4 -L parity1 /dev/sdZ1
   ```

2. **Mount the MergerFS Pool (`/mnt/media`):**
   Add the `disk1`, `disk2`, `parity1`, and `mergerfs` lines from [`config/fstab.example`](../config/fstab.example) to `/etc/fstab`, then run:
   ```bash
   sudo mount -a
   sudo mkdir -p /mnt/media/data/{torrents/{movies,tv,anime,music,books},media/{Films,TV,Anime}}
   sudo mkdir -p /mnt/media/temp_vault_staging
   sudo chown -R $USER:$USER /mnt/media
   ```

3. **Mount the Old NTFS `D:` (3 TB) and `E:` (4 TB) Drives Read-Only & Copy Data:**
   ```bash
   sudo mkdir -p /mnt/old_d /mnt/old_e
   sudo mount -t ntfs3 -o ro /dev/disk/by-label/Media\x20Drive /mnt/old_d
   sudo mount -t ntfs3 -o ro /dev/disk/by-label/Media\x20Drive\x202 /mnt/old_e

   # 1. Copy Staged Config Backups (Tautulli, Pi-hole, Unbound, Plex Preferences.xml) to /opt/docker/appdata
   cp -r /mnt/old_e/Migration_Backup/appdata/* /opt/docker/appdata/

   # 2. Copy Plex AppData & Database from D:\Plex to the fast 1 TB SSD (skipping temporary caches & Windows codecs)
   mkdir -p "/opt/docker/appdata/plex/Library/Application Support/Plex Media Server"
   rsync -avh --info=progress2 \
     --exclude='Cache/' --exclude='Codecs/' --exclude='Crash Reports/' --exclude='Diagnostics/' --exclude='Drivers/' --exclude='Logs/' --exclude='Updates/' \
     "/mnt/old_d/Plex/Plex Media Server/" \
     "/opt/docker/appdata/plex/Library/Application Support/Plex Media Server/"

   # Overwrite Preferences.xml with the Registry-converted Linux Preferences.xml from Migration_Backup:
   cp "/mnt/old_e/Migration_Backup/Preferences.xml" "/opt/docker/appdata/plex/Library/Application Support/Plex Media Server/Preferences.xml"

   # 3. Consolidate Films + Film 2, TV + TV 2, and Anime onto the 28 TB MergerFS Pool
   rsync -avh --info=progress2 "/mnt/old_d/Media/Films/" "/mnt/media/data/media/Films/"
   rsync -avh --info=progress2 "/mnt/old_e/Media/Film 2/" "/mnt/media/data/media/Films/"
   rsync -avh --info=progress2 "/mnt/old_d/Media/TV/" "/mnt/media/data/media/TV/"
   rsync -avh --info=progress2 "/mnt/old_e/Media/TV 2/" "/mnt/media/data/media/TV/"
   rsync -avh --info=progress2 "/mnt/old_e/Media/Anime/" "/mnt/media/data/media/Anime/"

   # 4. Stage Photos, Music, Audio, and Custom Art (~284 GB) onto the 28 TB pool temporarily
   rsync -avh --info=progress2 "/mnt/old_d/Media/Photos" "/mnt/media/temp_vault_staging/"
   rsync -avh --info=progress2 "/mnt/old_d/Media/Music" "/mnt/media/temp_vault_staging/"
   rsync -avh --info=progress2 "/mnt/old_d/Media/Audio" "/mnt/media/temp_vault_staging/"
   rsync -avh --info=progress2 "/mnt/old_d/Media/Custom Art" "/mnt/media/temp_vault_staging/"
   rsync -avh --info=progress2 "/mnt/old_e/Media/Custom Art/" "/mnt/media/temp_vault_staging/Custom Art/"
   ```

---

## Phase 4: Create the 3 TB Btrfs RAID 1 Vault (`/mnt/vault`)

1. **Verify All Data Has Copied Safely:**
   Check `du -sh /mnt/media/data/media/* /mnt/media/temp_vault_staging/*` to confirm sizes match:
   * `Films`: ~1,057 GB
   * `TV`: ~1,645 GB
   * `Anime`: ~999 GB
   * `Photos`: ~260 GB, `Music`: ~22 GB, `Audio`: ~1.3 GB

2. **Unmount Old `D:` & `E:` and Format as Btrfs RAID 1:**
   Identify the 3 TB WD (`WD30EZRZ`) and 4 TB Seagate (`ST4000DM004`) device names (`lsblk`), then run:
   ```bash
   sudo umount /mnt/old_d /mnt/old_e
   sudo wipefs -a /dev/sdA /dev/sdB
   sudo mkfs.btrfs -L Vault -d raid1 -m raid1 -f /dev/sdA /dev/sdB
   ```

3. **Mount `/mnt/vault` and Move Vault Data In:**
   Uncomment the `/mnt/vault` line in `/etc/fstab`, then run:
   ```bash
   sudo mount -a
   sudo mkdir -p /mnt/vault/Media /mnt/vault/Backups/docker-appdata
   sudo chown -R $USER:$USER /mnt/vault
   mv /mnt/media/temp_vault_staging/* /mnt/vault/Media/
   rmdir /mnt/media/temp_vault_staging
   ```

---

## Phase 5: Start the Docker Stack & Update Plex Library Paths

1. **Launch the Containers:**
   ```bash
   cp ~/MageeMedia/docker/compose.yaml /opt/docker/compose.yaml
   cp ~/MageeMedia/docker/.env.example /opt/docker/.env
   cp ~/MageeMedia/docker/unbound/pi-hole.conf /opt/docker/appdata/unbound/pi-hole.conf
   cd /opt/docker
   docker compose up -d
   ```

2. **Update Plex Library Folder Paths:**
   Open `http://192.168.1.237:32400/web`, edit each library (**Add folders**), and add the new container paths:
   * **Movies** → `/data/media/Films`
   * **TV Shows** → `/data/media/TV`
   * **Anime** → `/data/media/Anime`
   * **Photos** → `/data/vault/Photos/Finished Years`
   * **Music** → `/data/vault/Music`
   * **Audio Books** → `/data/vault/Audio`

   Wait for Plex to scan and match all items (watch history, custom posters, and collections will remain intact), then remove the old `D:\` and `E:\` paths and re-enable *"Empty trash automatically after every scan"*.
