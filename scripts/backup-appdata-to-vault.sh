#!/usr/bin/env bash
# =============================================================================
# MageeMedia Nightly Maintenance Script (Run via root cron at 03:30 AM)
# 1. Backs up /opt/docker/appdata from the 1 TB SSD to the 4 TB Btrfs Vault (/mnt/vault)
# 2. Mirrors the entire 4 TB Btrfs Vault (/mnt/vault) onto the 28 TB MergerFS Pool (/mnt/media/Backups/vault-mirror)
# 3. Runs SnapRAID sync & scrub on the 28 TB MergerFS Media Pool (protecting both Media + Vault Mirror)
# =============================================================================
set -euo pipefail

APPDATA_SRC="/opt/docker/appdata"
VAULT_BACKUP_DST="/mnt/vault/Backups/docker-appdata"
POOL_VAULT_MIRROR="/mnt/media/Backups/vault-mirror"

echo "[$(date -Is)] [1/4] Backing up Docker AppData from 1 TB SSD to 4 TB Btrfs Vault..."
mkdir -p "$VAULT_BACKUP_DST"

rsync -a --delete \
    --exclude='plex/Library/Application Support/Plex Media Server/Cache/' \
    --exclude='plex/Library/Application Support/Plex Media Server/Codecs/' \
    --exclude='plex/Library/Application Support/Plex Media Server/Crash Reports/' \
    --exclude='plex/Library/Application Support/Plex Media Server/Logs/' \
    --exclude='jellyfin/cache/' \
    --exclude='jellyfin/transcodes/' \
    --exclude='immich/thumbs/' \
    --exclude='immich/encoded-video/' \
    --exclude='qbittorrent/qBittorrent/ipc-socket' \
    "$APPDATA_SRC/" "$VAULT_BACKUP_DST/"

echo "[$(date -Is)] [2/4] Mirroring 4 TB Btrfs Vault (/mnt/vault) onto 28 TB Toshiba Pool ($POOL_VAULT_MIRROR)..."
mkdir -p "$POOL_VAULT_MIRROR"
rsync -a --delete /mnt/vault/ "$POOL_VAULT_MIRROR/"

echo "[$(date -Is)] [3/4] Running SnapRAID parity sync..."
snapraid sync

echo "[$(date -Is)] [4/4] Running SnapRAID 5% scrub..."
snapraid scrub -p 5 -o 30

echo "[$(date -Is)] Nightly maintenance complete."
