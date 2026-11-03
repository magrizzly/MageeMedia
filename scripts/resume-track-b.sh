#!/usr/bin/env bash
# =============================================================================
# MageeMedia Track B Continuation (Fault-Tolerant)
# 1. Immediately evacuates irreplaceable Photos, Music, Audio, Custom Art &
#    TV Names.aren from /mnt/old_d to /mnt/vault/Media/
# 2. Starts Plex, Jellyfin, Immich, and *arr containers as soon as Vault media
#    is in place
# 3. Evacuates remaining /mnt/old_d/Media/TV/ to /mnt/disk1/data/media/TV/
# 4. Runs nightly backup/vault-mirror + initial SnapRAID sync
# =============================================================================
set -uo pipefail

LOG_DIR=/var/log/mageemedia-migration
ERR_LOG="$LOG_DIR/read_errors.log"
mkdir -p "$LOG_DIR"

echo "[$(date -Is)] [Step 1/4] Evacuating irreplaceable Photos, Music, Audio, Custom Art from /mnt/old_d to /mnt/vault/Media/..."
rsync -a --info=progress2 '/mnt/old_d/Media/Photos' '/mnt/vault/Media/' 2>>"$ERR_LOG" || echo "[WARN] rsync Photos exited with code $?"
rsync -a --info=progress2 '/mnt/old_d/Media/Music' '/mnt/vault/Media/' 2>>"$ERR_LOG" || echo "[WARN] rsync Music exited with code $?"
rsync -a --info=progress2 '/mnt/old_d/Media/Audio' '/mnt/vault/Media/' 2>>"$ERR_LOG" || echo "[WARN] rsync Audio exited with code $?"
rsync -a --info=progress2 '/mnt/old_d/Media/Custom Art/' '/mnt/vault/Media/Custom Art/' 2>>"$ERR_LOG" || echo "[WARN] rsync Custom Art exited with code $?"
if [ -f '/mnt/old_d/Media/TV Names.aren' ]; then
    cp -a '/mnt/old_d/Media/TV Names.aren' '/mnt/vault/Media/' 2>>"$ERR_LOG" || true
fi
chown -R charlie:charlie /mnt/vault
sync

echo "[$(date -Is)] [Step 2/4] Vault Media complete! Launching Plex, Jellyfin, Immich, and *arr containers..."
cd /opt/docker
docker compose up -d plex jellyfin immich-redis immich-postgres immich-machine-learning immich-server sonarr radarr lidarr readarr bazarr

echo "[$(date -Is)] [Step 3/4] Evacuating /mnt/old_d/Media/TV/ to /mnt/disk1/data/media/TV/..."
rsync -a --info=progress2 '/mnt/old_d/Media/TV/' '/mnt/disk1/data/media/TV/' 2>>"$ERR_LOG" || echo "[WARN] rsync TV exited with code $?"
chown -R charlie:charlie /mnt/disk1 /mnt/disk2 /mnt/vault
sync

echo "[$(date -Is)] [Step 4/4] All media copied! Running Vault mirror + initial SnapRAID parity sync..."
touch "$LOG_DIR/complete.flag"
/usr/local/bin/backup-appdata-to-vault.sh || echo "[WARN] initial backup/snapraid exited with code $?"
echo "[$(date -Is)] ALL MIGRATION & POST-MIGRATION STEPS COMPLETE!" | tee "$LOG_DIR/post_complete.flag"
