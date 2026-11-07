# Agent Context & Session Handoff — MageeMedia 2.0 Migration

This file provides complete context for AI agents (Antigravity) when opening this repository on another machine or via Remote-SSH.

---

## 1. Current Migration Status (COMPLETE)
* **Phase 1 (Windows 10 Config Export): COMPLETE**
* **Phase 2 (Ubuntu 24.04 LTS Host Install & Bootstrap): COMPLETE**
  * Ubuntu Server installed on the **1 TB Innodisk SSD (`sdb`)**.
  * Static IP `192.168.1.237/24` (Gateway `192.168.1.254`, DNS `127.0.0.1, 1.1.1.1`) locked in Netplan.
  * Docker, Docker Compose, Tailscale (Subnet Router pre-configured), MergerFS, SnapRAID, Btrfs, Samba, and Cockpit (`https://192.168.1.237:9090`) installed.
* **Phase 3 & 4 (14 TB Pool + 4 TB Btrfs Vault + Media Evacuation): COMPLETE**
  * 3× 14 TB Toshiba (`sda1`=`disk1`, `sdc1`=`disk2`, `sdd1`=`parity1`) formatted (`ext4 -m 0 -T largefile4`) and pooled via MergerFS at `/mnt/media` (28 TB / 26 TiB usable).
  * 4 TB Seagate (`sde1`=`Vault`) formatted as Btrfs (`/mnt/vault`) with `zstd:3` compression and `DUP` metadata checksums.
  * All media evacuated and verified (`Films` 1.1 TB, `TV` 1.7 TB, `Anime` 999 GB, `Music` 23 GB, `Audio` 1.3 GB, `Custom Art` 592 MB on `/mnt/media/data/media`; `Photos` 260 GB and `docker-appdata` backup 60 GB on `/mnt/vault`).
  * Both the **3 TB WD Blue (`WD-WCC4N7KRH2J2`)** and **64 GB SanDisk SSD (`134728400405`)** have been physically removed, cables tidied, and the server relocated to its permanent home in the loft.
* **Phase 5 (Docker Stack Launch, Plex SQLite Path Remap & Full Service Wiring): COMPLETE**
  * All 22 containers in `/opt/docker/compose.yaml` are up and healthy (including `Plex`, `Jellyfin`, `JellyPlex-Watched` 2-way watch sync, `Immich`, `Gluetun` ProtonVPN + NAT-PMP for `qBittorrent` & `Prowlarr`, `FlareSolverr`, `Requestrr`, `Seerr` (migrated from deprecated Jellyseerr), `Tautulli`, `Pi-hole v6`, `Unbound`, and the `*arr` suite).
  * `com.plexapp.plugins.library.db` paths directly updated from Windows `D:\` & `E:\` to `/data/media/*` & `/data/vault/*` via `scripts/remap-plex-paths.sh`, and `autoEmptyTrash="1"` re-enabled in `Preferences.xml`.
  * All `*arr` apps (`Radarr`, `Sonarr`, `Lidarr`, `Readarr`) are wired to `Prowlarr` indexers and `qBittorrent` (`gluetun:8080`, with subnet whitelist `172.16.0.0/12, 192.168.1.0/24` enabled), `Bazarr` is configured with a default `English` subtitle profile and providers (`opensubtitlescom`, `podnapisi`, `gestdown`, `yifysubtitles`), `Seerr` is linked to `Jellyfin`, `Radarr`, and `Sonarr` with all 6 users imported, and `Requestrr` is pre-wired to `Seerr`, `Radarr`, and `Sonarr`.

---

## 2. Exact Hardware & Drive Inventory (`MageeMedia` — `192.168.1.237`)

* **Motherboard:** ASUS ROG MAXIMUS VI HERO (Intel Z87, 6× Intel Z87 SATA ports `SATA6G_1`–`6` + 2× ASMedia SATA ports `SATA6G_E1`/`E2`)
* **CPU / iGPU:** Intel Core i7-4790 @ 3.60GHz (`Intel HD Graphics 4600` passed into Plex, Jellyfin & Immich via `/dev/dri`)
* **RAM:** 32 GB DDR3 (`/dev/shm` used for RAM-disk transcoding)

| SATA Port / Device | Drive Model & Serial | Size | Permanent Role |
| :--- | :--- | :--- | :--- |
| **`SATA6G_1` (`sda`)** | Toshiba `MG07ACA14TE` (`Y8K0A07GF94G`) | 14 TB | **Tier 2 (`/mnt/disk1`):** MergerFS Data Disk 1 |
| **`SATA6G_2` (`sdb`)** | Innodisk `DES25-01TDK1KCCQL` (`BCA12211160180004`) | 1 TB | **Tier 1 (`/` & `/opt/docker`):** Ubuntu OS, Docker AppData, Immich DB/Thumbs, Incomplete Torrent Cache |
| **`SATA6G_3` (`sdc`)** | Toshiba `MG07ACA14TE` (`Y8X0A0EKF94G`) | 14 TB | **Tier 2 (`/mnt/disk2`):** MergerFS Data Disk 2 |
| **`SATA6G_4` (`sdd`)** | Toshiba `MG07ACA14TE` (`X860A026F94G`) | 14 TB | **Tier 2 (`/mnt/parity1`):** SnapRAID Parity Disk (protects 28 TB Pool + Vault Mirror) |
| **`SATA6G_6` (`sde`)** | Seagate `ST4000DM004-2CV104` (`WFN6GEFD`) | 4 TB | **Tier 3 (`/mnt/vault`):** 4 TB Btrfs Vault |

---

## 3. Server Access & Credentials Hint
* **Host:** `192.168.1.237` (`MageeMedia`)
* **Default Admin User:** `charlie` (UID `1000:1000`)
* **Password Hint:** "Gamertag then media"
* **SSH Key Auth:** Configured from `CHARLIE-PC` (`~/.ssh/id_ed25519.pub`)
