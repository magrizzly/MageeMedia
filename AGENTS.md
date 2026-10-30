# Agent Context & Session Handoff — MageeMedia 2.0 Migration

This file provides complete context for AI agents (Antigravity) when opening this repository on another machine or via Remote-SSH.

---

## 1. Current Migration Status (Where We Left Off)
* **Phase 1 (Windows 10 Config Export) is COMPLETE:**
  * `scripts/export-windows-configs.ps1` has already been executed on the Windows 10 host.
  * All exported configurations are staged on the 4 TB Seagate drive (`Media Drive 2`) under `/Migration_Backup` (Windows path `E:\Migration_Backup`):
    * `Migration_Backup/Preferences.xml` — Pre-converted Linux Plex `Preferences.xml` generated from `HKCU\Software\Plex, Inc.\Plex Media Server` (with `autoEmptyTrash="0"` set for safe library path migration).
    * `Migration_Backup/plex_registry_backup.reg` — Full raw Registry backup.
    * `Migration_Backup/appdata/tautulli/` — Contains `tautulli.db`, `backups/`, `newsletters/`, and `config.ini` (already updated with `/config/...` Linux paths and `192.168.1.237`).
    * `Migration_Backup/appdata/pihole/` — Contains `etc-pihole/` (`pihole.toml`, `gravity.db`, `pihole-FTL.db`, `cli_pw`, `dnsmasq.conf`) and `etc-dnsmasq.d/` (`05-pihole-custom-cname.conf`).
    * `Migration_Backup/appdata/unbound/pi-hole.conf` — Recursive DoT Unbound config (port `5335`).
    * `Migration_Backup/appdata/deluge/` — Legacy Deluge state & config backup.
  * **Plex AppData & Databases (`~213 MB` SQLite DB + Metadata):** Currently still on the 3 TB WD Blue drive (`Media Drive`) under `/Plex/Plex Media Server` (Windows path `D:\Plex\Plex Media Server`).

* **Next Action Required (Phases 2–5 in `docs/MIGRATION_GUIDE.md`):**
  1. Connect to `192.168.1.237` (`MageeMedia`) over SSH once Ubuntu Server 24.04 LTS is installed on the **1 TB Innodisk SSD (`DES25-01TDK1KCCQL`)**.
  2. Run `sudo bash scripts/setup-ubuntu-host.sh` to install Docker, MergerFS, SnapRAID, Btrfs tools, Samba, and Cockpit, and free port `53` (`DNSStubListener=no`).
  3. Partition and format the **3× 14 TB Toshiba (`MG07ACA14TE`)** drives as `ext4` (`-m 0 -T largefile4`, labels `disk1`, `disk2`, `parity1`) and mount the **28 TB MergerFS pool** at `/mnt/media`.
  4. **CRITICAL ORDER:** Mount the old NTFS 3 TB (`Media Drive`, serial `WD-WCC4N7KRH2J2`) and 4 TB (`Media Drive 2`, serial `WFN6GEFD`) drives **read-only**, and evacuate all ~4.0 TB of data + `Migration_Backup` + `Plex/Plex Media Server` onto the 28 TB MergerFS pool (`/mnt/media`) and 1 TB SSD (`/opt/docker/appdata`) **BEFORE** formatting the 3 TB and 4 TB drives as the **Btrfs RAID 1 Vault** (`/mnt/vault`).
  5. Format the 3 TB + 4 TB drives as Btrfs RAID 1 (`mkfs.btrfs -L Vault -d raid1 -m raid1`), move `Photos`, `Music`, `Audio`, and `Custom Art` from `/mnt/media/temp_vault_staging` into `/mnt/vault/Media/`, run `snapraid sync`, and launch `/opt/docker/compose.yaml`.

---

## 2. Exact Hardware & Drive Inventory (`MageeMedia` — `192.168.1.237`)

* **Motherboard:** ASUS ROG MAXIMUS VI HERO (Intel Z87, 6× Intel Z87 SATA ports `SATA6G_1`–`6` + 2× ASMedia SATA ports `SATA6G_E1`/`E2`)
* **CPU / iGPU:** Intel Core i7-4790 @ 3.60GHz (`Intel HD Graphics 4600` passed into Plex & Jellyfin via `/dev/dri`)
* **RAM:** 32 GB DDR3 (`/dev/shm` used for RAM-disk transcoding)

| Drive Model | Serial / Identifier | Size | Current / Target Role |
| :--- | :--- | :--- | :--- |
| **Innodisk `DES25-01TDK1KCCQL`** | 1 TB 2.5" SATA SSD | 1 TB | **Tier 1 (`/` & `/opt/docker`):** Ubuntu 24.04 OS, Docker `/config` AppData, `/opt/docker/downloads/incomplete` SSD torrent cache |
| **3× Toshiba `MG07ACA14TE`** | 3× 14 TB 3.5" SATA HDD | 42 TB raw | **Tier 2 (`/mnt/media`):** 2× 14 TB Data (`disk1`, `disk2` pooled via MergerFS = 28 TB usable) + 1× 14 TB SnapRAID Parity (`parity1`) |
| **WDC `WD30EZRZ-00Z5HB0`** | `WD-WCC4N7KRH2J2` (Label: `Media Drive`) | 3 TB | Currently holds NTFS `D:\Media` (`Films`, `TV`, `Photos`, `Music`, `Audio`, `Custom Art`) + `D:\Plex`. **Target:** Member A of 3 TB Btrfs RAID 1 Vault (`/mnt/vault`) |
| **Seagate `ST4000DM004-2CV104`** | `WFN6GEFD` (Label: `Media Drive 2`) | 4 TB | Currently holds NTFS `E:\Media` (`Anime`, `Film 2`, `TV 2`) + `E:\Migration_Backup`. **Target:** Member B of 3 TB Btrfs RAID 1 Vault (`/mnt/vault`) |
| **SanDisk `SDSSDHP064G`** | `134728400405` (Label: `60GB Sandisk SSD`) | 64 GB | Old Windows 10 `C:` drive on `SATA6G_E1` (Read-only fallback `/mnt/win_c`) |

---

## 3. Existing Media Folder Sizes (To Verify After Evacuating `D:` & `E:`)
* **Consolidating onto 28 TB MergerFS Pool (`/mnt/media/data/media/`):**
  * `Films` (`1,025.97 GB` on `D:` + `31.50 GB` in `E:\Media\Film 2` = **`1,057.47 GB`**)
  * `TV` (`1,316.59 GB` on `D:` + `328.33 GB` in `E:\Media\TV 2` = **`1,644.92 GB`**)
  * `Anime` (`998.52 GB` on `E:\Media\Anime`)
* **Moving to 3 TB Btrfs RAID 1 Vault (`/mnt/vault/Media/`):**
  * `Photos` (`259.43 GB` — Plex library points to `Photos/Finished Years`)
  * `Music` (`22.32 GB`)
  * `Audio` (`1.26 GB` — Audiobooks)
  * `Custom Art` (`0.58 GB`)
