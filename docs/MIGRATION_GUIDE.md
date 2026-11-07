# Step-by-Step Windows 10 to Ubuntu 24.04 Migration Guide

This guide documents the zero-data-loss migration from Windows 10 onto the **1 TB Innodisk SSD**, **3× 14 TB Toshiba (`MG07ACA14TE`)** MergerFS + SnapRAID pool (`28 TB` usable), and **4 TB Seagate Btrfs Vault** (mirrored nightly onto the 28 TB pool), keeping the **3 TB WD Blue** as an untouched offline cold backup.

---

## Phase 1: Pre-Flight Steps on Windows 10 (Completed)
1. Disabled Windows Hibernation (`powercfg /h off`).
2. Disabled "Auto Empty Trash" in Plex (`autoEmptyTrash="0"`).
3. Ran `scripts/export-windows-configs.ps1` to generate `/mnt/old_e/Migration_Backup` (Linux `Preferences.xml`, Tautulli DB/config, Pi-hole v6, Unbound DoT).

---

## Phase 2: Ubuntu 24.04 LTS Host Setup (Completed)
1. Installed Ubuntu Server 24.04 LTS onto the **1 TB Innodisk SSD (`sdb`)**.
2. Ran `sudo bash ~/MageeMedia/scripts/setup-ubuntu-host.sh` to install:
   * Docker Engine & Docker Compose plugin
   * Tailscale (with IPv4/IPv6 forwarding enabled for Subnet Routing `192.168.1.0/24`)
   * MergerFS, SnapRAID, Btrfs tools, Samba (`\\192.168.1.237\Media` & `\Vault`), and Cockpit (`https://192.168.1.237:9090`)
   * Locked static IP `192.168.1.237/24` (Gateway `192.168.1.254`, DNS `127.0.0.1, 1.1.1.1`) and freed Port 53 for Pi-hole.

---

## Phase 3 & 4: Dual-Stream Parallel Media Evacuation & 4 TB Btrfs Vault Creation
Executed automatically by [`scripts/run-media-migration.sh`](../scripts/run-media-migration.sh) (`mageemedia-migration.service`):
1. **3× 14 TB Toshiba Drives (`sda1`=`disk1`, `sdc1`=`disk2`, `sdd1`=`parity1`):**
   * Formatted with `mkfs.ext4 -m 0 -T largefile4` and pooled via MergerFS at `/mnt/media` (`26 TiB` / `28 TB` usable).
2. **1 TB SSD AppData Migration (`/opt/docker/appdata`):**
   * Copied `Migration_Backup/appdata/*` (Pi-hole v6, Unbound, Tautulli) and `55 GB` of `Plex Media Server` database & metadata (with converted `Preferences.xml`) to `/opt/docker/appdata`.
3. **Dual-Stream Sequential Media Evacuation (~250 MB/s combined):**
   * **Stream A (`4 TB Seagate` `/mnt/old_e` → `14 TB Toshiba #2` `/mnt/disk2`):** Evacuates `Film 2`, `TV 2`, `Anime`, and `Custom Art`, then automatically formats `/dev/sdf1` as the **4 TB Btrfs Vault (`/mnt/vault`)** with `zstd:3` compression and `dup` metadata.
   * **Stream B (`3 TB WD Blue` `/mnt/old_d` → `14 TB Toshiba #1` `/mnt/disk1`):** Evacuates `Films` and `TV` in parallel with zero disk contention, then streams `Photos` (`260 GB`), `Music` (`22 GB`), `Audio` (`1.3 GB`), and `Custom Art` straight into `/mnt/vault/Media/`.
4. **Offline Cold Backup:**
   * The **3 TB WD Blue (`sde`)** and **64 GB SanDisk SSD (`sdg`)** are never written to or wiped—unplug them when tidying the case to keep an untouched offline cold backup on your shelf.

---

## Phase 5: Docker Stack Launch & Final Configuration (Completed)
1. **Containers (`/opt/docker/compose.yaml`):**
   * **Plex**, **Jellyfin**, **JellyPlex-Watched**, **Tautulli**, **Seerr** (formerly Jellyseerr), **Requestrr** (Telegram/Discord bot), **Immich** (Server, ML, Redis, Postgres), **Gluetun** (ProtonVPN WireGuard + NAT-PMP) routing **qBittorrent** & **Prowlarr**, **FlareSolverr**, **Sonarr**, **Radarr**, **Lidarr**, **Readarr**, **Bazarr**, **Pi-hole v6**, and **Unbound**.
2. **Plex Library Folder Paths (`http://192.168.1.237:32400/web`):**
   * **Movies** → `/data/media/Films`
   * **TV Shows** → `/data/media/TV`
   * **Anime** → `/data/media/Anime`
   * **Photos** → `/data/vault/Photos/Finished Years`
   * **Music** → `/data/media/Music`
   * **Audio Books** → `/data/media/Audio`
   *(Remapped in SQLite via `scripts/remap-plex-paths.sh` and re-enabled `autoEmptyTrash="1"` in `Preferences.xml`).*
