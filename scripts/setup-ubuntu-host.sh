#!/usr/bin/env bash
# =============================================================================
# MageeMedia Ubuntu 24.04 LTS Host Setup Script
# Installs Docker Engine, MergerFS, SnapRAID, Btrfs, Samba, and Cockpit,
# frees port 53 for Pi-hole, and prepares mount points & /opt/docker.
# =============================================================================
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
   echo "Please run as root: sudo bash $0"
   exit 1
fi

TARGET_USER="${SUDO_USER:-$USER}"
echo "=== Configuring MageeMedia Ubuntu Host for user: $TARGET_USER ==="

# 1. Install System Packages (MergerFS, SnapRAID, Btrfs, Samba, Cockpit, rsync)
apt-get update
apt-get install -y \
    ca-certificates curl gnupg lsb-release \
    mergerfs snapraid btrfs-progs parted rsync \
    samba cockpit cockpit-storaged smartmontools

# 2. Install Official Docker Engine & Docker Compose Plugin
if ! command -v docker &> /dev/null; then
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    usermod -aG docker "$TARGET_USER"
fi

# 3. Add User to 'render' and 'video' Groups for Intel QuickSync (/dev/dri)
usermod -aG render,video "$TARGET_USER"

# 4. Disable systemd-resolved Stub Listener on Port 53 (Required for Pi-hole)
if grep -q "^#DNSStubListener=yes" /etc/systemd/resolved.conf 2>/dev/null; then
    sed -i 's/^#DNSStubListener=yes/DNSStubListener=no/' /etc/systemd/resolved.conf
    ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf
    systemctl restart systemd-resolved
    echo "  -> Freed port 53 for Pi-hole container."
fi

# 5. Create Mount Points & Docker Directory Structure on the 1 TB SSD
mkdir -p /mnt/{disk1,disk2,parity1,media,vault,win_c}
mkdir -p /opt/docker/appdata/{dockge,plex,jellyfin,tautulli,jellyseerr,qbittorrent,prowlarr,sonarr,radarr,lidarr,readarr,bazarr,pihole/etc-pihole,pihole/etc-dnsmasq.d,unbound}
mkdir -p /opt/docker/downloads/incomplete

chown -R "$TARGET_USER:$TARGET_USER" /opt/docker

# 6. Install SnapRAID configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cp "$SCRIPT_DIR/../config/snapraid.conf" /etc/snapraid.conf

echo "=== Host setup complete! Cockpit is available at https://$(hostname -I | awk '{print $1}'):9090 ==="
