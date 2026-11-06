#!/usr/bin/env bash
# =============================================================================
# MageeMedia Ubuntu 24.04 LTS Host Setup Script
# Installs Docker Engine, Tailscale (Subnet Router ready), MergerFS, SnapRAID,
# Btrfs, Samba, and Cockpit, locks static IP + DNS fallback, frees port 53
# for Pi-hole, and prepares mount points & /opt/docker.
# =============================================================================
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
   echo "Please run as root: sudo bash $0"
   exit 1
fi

TARGET_USER="${SUDO_USER:-charlie}"
echo "=== Configuring MageeMedia Ubuntu Host for user: $TARGET_USER ==="

# 1. Install System Packages (MergerFS, SnapRAID, Btrfs, Samba, Cockpit, rsync, iGPU tools)
apt-get update
apt-get install -y \
    ca-certificates curl gnupg lsb-release \
    mergerfs snapraid btrfs-progs parted rsync jq \
    samba cockpit cockpit-storaged smartmontools intel-gpu-tools

# 2. Install Official Docker Engine & Docker Compose Plugin
if ! command -v docker &> /dev/null; then
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor --yes -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi
usermod -aG docker "$TARGET_USER"

# 3. Install Official Tailscale & Enable IP Forwarding for Subnet Routing (192.168.1.0/24)
if ! command -v tailscale &> /dev/null; then
    curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/noble.noarmor.gpg | tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
    curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/noble.tailscale-keyring.list | tee /etc/apt/sources.list.d/tailscale.list
    apt-get update
    apt-get install -y tailscale
fi
cat << 'EOF' > /etc/sysctl.d/99-tailscale.conf
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
EOF
sysctl -p /etc/sysctl.d/99-tailscale.conf

# 4. Add User to 'render' and 'video' Groups for Intel QuickSync (/dev/dri)
usermod -aG render,video "$TARGET_USER"

# 5. Configure Static IP (192.168.1.237/24) & Fallback DNS (127.0.0.1 + 1.1.1.1) in Netplan
cat << 'EOF' > /etc/netplan/00-installer-config.yaml
network:
  version: 2
  ethernets:
    eno1:
      dhcp4: false
      dhcp6: true
      addresses:
        - 192.168.1.237/24
      routes:
        - to: default
          via: 192.168.1.254
      nameservers:
        addresses:
          - 127.0.0.1
          - 1.1.1.1
          - 9.9.9.9
      match:
        macaddress: e0:3f:49:b1:69:2f
      set-name: eno1
EOF
chmod 600 /etc/netplan/00-installer-config.yaml
netplan apply

# 6. Disable systemd-resolved Stub Listener on Port 53 (Required for Pi-hole)
sed -i 's/^#*DNSStubListener=.*/DNSStubListener=no/' /etc/systemd/resolved.conf
ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf
systemctl restart systemd-resolved
echo "  -> Freed port 53 for Pi-hole container and locked 192.168.1.237 static IP."

# 7. Create Mount Points & Docker Directory Structure on the 1 TB SSD
mkdir -p /mnt/{disk1,disk2,parity1,media,vault,old_d,old_e}
mkdir -p /opt/docker/appdata/{dockge,plex,jellyfin,tautulli,seerr,requestrr,gluetun,qbittorrent,prowlarr,sonarr,radarr,lidarr,readarr,bazarr,pihole/etc-pihole,pihole/etc-dnsmasq.d,unbound,immich/postgres,immich/thumbs,immich/encoded-video,immich/model-cache}
mkdir -p /opt/docker/downloads/incomplete

chown -R "$TARGET_USER:$TARGET_USER" /opt/docker

# 8. Install SnapRAID configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cp "$SCRIPT_DIR/../config/snapraid.conf" /etc/snapraid.conf

# 9. Configure Samba Shares (\Media and \Vault) if not already added
if ! grep -q "^\[Media\]" /etc/samba/smb.conf; then
    cat "$SCRIPT_DIR/../config/smb.conf.example" >> /etc/samba/smb.conf
    systemctl restart smbd nmbd || true
fi

# 10. Ensure Docker & Samba wait for MergerFS (/mnt/media) and Btrfs Vault (/mnt/vault) on cold boot
mkdir -p /etc/systemd/system/docker.service.d /etc/systemd/system/smbd.service.d
cat << 'EOF' | tee /etc/systemd/system/docker.service.d/wait-for-mounts.conf /etc/systemd/system/smbd.service.d/wait-for-mounts.conf > /dev/null
[Unit]
Wants=mnt-disk1.mount mnt-disk2.mount mnt-parity1.mount mnt-media.mount mnt-vault.mount
After=mnt-disk1.mount mnt-disk2.mount mnt-parity1.mount mnt-media.mount mnt-vault.mount
EOF
systemctl daemon-reload

echo "=== Host setup complete! Cockpit is available at https://192.168.1.237:9090 ==="
