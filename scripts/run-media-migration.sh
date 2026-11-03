#!/usr/bin/env bash
# =============================================================================
# MageeMedia Dual-Stream Parallel Media Evacuation & Btrfs Vault Builder
# - Stream A: Evacuates 4 TB Seagate (/mnt/old_e -> /mnt/disk2), formats
#   /dev/sdf1 as the 4 TB Btrfs Vault (/mnt/vault), and mounts it.
# - Stream B: Evacuates 3 TB WD Blue Films & TV (/mnt/old_d -> /mnt/disk1)
#   in parallel with zero disk contention, then streams Photos, Music, Audio,
#   and Custom Art directly into the freshly formatted /mnt/vault/Media.
# =============================================================================
set -euo pipefail

LOG_DIR=/var/log/mageemedia-migration
mkdir -p "$LOG_DIR"
mkdir -p /mnt/disk1/data/media/{Films,TV,Anime}
mkdir -p /mnt/disk2/data/media/{Films,TV,Anime}
mkdir -p '/mnt/disk2/temp_vault_staging/Custom Art'

track_a() {
    echo "[$(date -Is)] [Track A] Starting evacuation of 4 TB Seagate (/mnt/old_e -> /mnt/disk2)..."
    rsync -a --info=progress2 '/mnt/old_e/Media/Film 2/' '/mnt/disk2/data/media/Films/'
    rsync -a --info=progress2 '/mnt/old_e/Media/TV 2/' '/mnt/disk2/data/media/TV/'
    rsync -a --info=progress2 '/mnt/old_e/Media/Anime/' '/mnt/disk2/data/media/Anime/'
    rsync -a --info=progress2 '/mnt/old_e/Media/Custom Art/' '/mnt/disk2/temp_vault_staging/Custom Art/'
    sync

    echo "[$(date -Is)] [Track A] /mnt/old_e evacuation complete! Formatting /dev/sdf as 4 TB Btrfs Vault (/mnt/vault)..."
    umount /mnt/old_e
    wipefs -a /dev/sdf
    parted -s /dev/sdf mklabel gpt mkpart primary btrfs 0% 100%
    partprobe /dev/sdf
    sleep 2
    mkfs.btrfs -L Vault -m dup -f /dev/sdf1

    sed -i 's|^# *LABEL=Vault|LABEL=Vault|' /etc/fstab
    systemctl daemon-reload
    mount /mnt/vault
    mkdir -p /mnt/vault/Media/Photos/Immich_Uploads
    mkdir -p '/mnt/vault/Media/Custom Art'
    mkdir -p /mnt/vault/Backups/docker-appdata

    rsync -a '/mnt/disk2/temp_vault_staging/Custom Art/' '/mnt/vault/Media/Custom Art/'
    rm -rf /mnt/disk2/temp_vault_staging
    chown -R charlie:charlie /mnt/vault
    touch "$LOG_DIR/vault_ready.flag"
    echo "[$(date -Is)] [Track A] /mnt/vault is formatted, mounted, and ready!"
}

track_b() {
    echo "[$(date -Is)] [Track B] Starting evacuation of 3 TB WD Blue Films and TV (/mnt/old_d -> /mnt/disk1)..."
    rsync -a --info=progress2 '/mnt/old_d/Media/Films/' '/mnt/disk1/data/media/Films/'
    rsync -a --info=progress2 '/mnt/old_d/Media/TV/' '/mnt/disk1/data/media/TV/'
    sync
    echo "[$(date -Is)] [Track B] /mnt/old_d Films and TV complete! Waiting for /mnt/vault to be ready..."
    while [ ! -f "$LOG_DIR/vault_ready.flag" ]; do
        sleep 5
    done
    echo "[$(date -Is)] [Track B] Copying Photos, Music, Audio, Custom Art and TV Names.aren directly from /mnt/old_d to /mnt/vault/Media/..."
    rsync -a --info=progress2 '/mnt/old_d/Media/Photos' '/mnt/vault/Media/'
    rsync -a --info=progress2 '/mnt/old_d/Media/Music' '/mnt/vault/Media/'
    rsync -a --info=progress2 '/mnt/old_d/Media/Audio' '/mnt/vault/Media/'
    rsync -a --info=progress2 '/mnt/old_d/Media/Custom Art/' '/mnt/vault/Media/Custom Art/'
    if [ -f '/mnt/old_d/Media/TV Names.aren' ]; then
        cp -a '/mnt/old_d/Media/TV Names.aren' '/mnt/vault/Media/'
    fi
    sync
    echo "[$(date -Is)] [Track B] All /mnt/old_d data copied!"
}

rm -f "$LOG_DIR/vault_ready.flag" "$LOG_DIR/complete.flag"
track_a > "$LOG_DIR/track_a.log" 2>&1 &
PID_A=$!
track_b > "$LOG_DIR/track_b.log" 2>&1 &
PID_B=$!

wait $PID_A
wait $PID_B

chown -R charlie:charlie /mnt/disk1 /mnt/disk2 /mnt/vault
echo "[$(date -Is)] ALL MEDIA MIGRATION COMPLETE!" | tee "$LOG_DIR/complete.flag"
