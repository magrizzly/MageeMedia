#!/usr/bin/env bash
# =============================================================================
# MageeMedia Post-Migration Finisher
# Waits for run-media-migration.sh to finish, starts all media & *arr
# containers, mirrors /mnt/vault to the 28 TB pool, and runs initial SnapRAID sync.
# =============================================================================
set -euo pipefail

LOG_DIR=/var/log/mageemedia-migration
echo "[$(date -Is)] Waiting for media migration ($LOG_DIR/complete.flag) to finish..."
while [ ! -f "$LOG_DIR/complete.flag" ]; do
    sleep 15
done

echo "[$(date -Is)] Media migration finished! Starting Plex, Jellyfin, Immich, and *arr containers..."
cd /opt/docker
docker compose up -d plex jellyfin immich-redis immich-postgres immich-machine-learning immich-server sonarr radarr lidarr readarr bazarr

echo "[$(date -Is)] Running initial Vault mirror and SnapRAID parity sync..."
/usr/local/bin/backup-appdata-to-vault.sh

echo "[$(date -Is)] POST-MIGRATION COMPLETE!" | tee "$LOG_DIR/post_complete.flag"
