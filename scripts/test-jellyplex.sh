#!/usr/bin/env bash
set -e
PLEX_TOKEN=$(sudo grep '^PLEX_TOKEN=' /opt/docker/.env | cut -d= -f2)
JELLYFIN_TOKEN=$(sudo grep '^JELLYFIN_TOKEN=' /opt/docker/.env | cut -d= -f2)

echo "Plex token length: ${#PLEX_TOKEN}"
echo "Jellyfin token length: ${#JELLYFIN_TOKEN}"

sudo docker run --rm \
  -e DRYRUN=True \
  -e DEBUG=True \
  -e RUN_ONLY_ONCE=True \
  -e PLEX_BASEURL=http://192.168.1.237:32400 \
  -e PLEX_TOKEN="${PLEX_TOKEN}" \
  -e JELLYFIN_BASEURL=http://192.168.1.237:8096 \
  -e JELLYFIN_TOKEN="${JELLYFIN_TOKEN}" \
  -e USER_MAPPING='{"Magrizzly": "magrizzly", "Magoober": "Harry"}' \
  -e LIBRARY_MAPPING='{"TV Shows": "Shows"}' \
  -e WHITELIST_USERS=Magrizzly,magrizzly,Magoober,Harry \
  luigi311/jellyplex-watched:latest
