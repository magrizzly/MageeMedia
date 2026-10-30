#!/usr/bin/env bash
# =============================================================================
# MageeMedia Nightly Maintenance Script (Run via root cron at 03:30 AM)
# 1. Backs up /opt/docker/appdata from the 1 TB SSD to the 3 TB Btrfs RAID 1 Vault
# 2. Runs SnapRAID sync & scrub on the 28 TB MergerFS Media Pool
# =============================================================================
set -euo pipefail

APPDATA_SRC="/opt/docker/appdata"
VAULT_BACKUP_DST="/mnt/vault/Backups/docker-appdata"

echo "[$(date -Is)] Starting nightly Docker AppData backup to Btrfs RAID 1 Vault..."
mkdir -p "$VAULT_BACKUP_DST"

rsync -a --delete \
    --exclude='plex/Library/Application Support/Plex Media Server/Cache/' \
    --exclude='plex/Library/Application Support/Plex Media Server/Codecs/' \
    --exclude='plex/Library/Application Support/Plex Media Server/Crash Reports/' \
    --exclude='plex/Library/Application Support/Plex Media Server/Logs/' \
    --exclude='jellyfin/cache/' \
    --exclude='jellyfin/transcodes/' \
    "$APPDATA_SRC/" "$VAULT_BACKUP_DST/"

echo "[$(date -Is)] Running SnapRAID parity sync..."
snapraid sync

echo "[$(date -Is)] Running SnapRAID 5% scrub..."
snapraid scrub -p 5 -o 30

echo "[$(date -Is)] Nightly maintenance complete."
