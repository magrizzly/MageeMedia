#!/usr/bin/env bash
# =============================================================================
# MageeMedia Plex Database Windows-to-Linux Path Remapper
# Directly updates section_locations, media_items, media_parts, and
# media_streams in com.plexapp.plugins.library.db while Plex is stopped so all
# Windows D:\ and E:\ paths map immediately to /data/media/* and /data/vault/*.
# =============================================================================
set -euo pipefail

DB_DIR="/opt/docker/appdata/plex/Library/Application Support/Plex Media Server/Plug-in Support/Databases"
DB_HOST="$DB_DIR/com.plexapp.plugins.library.db"
DB_CONTAINER="/config/Library/Application Support/Plex Media Server/Plug-in Support/Databases/com.plexapp.plugins.library.db"

echo "[1/4] Stopping Plex container cleanly and backing up database..."
sudo docker stop plex
sudo cp -a "$DB_HOST" "/opt/docker/appdata/plex/com.plexapp.plugins.library.db.bak-latest"

echo "[2/4] Running SQLite path updates via Plex SQLite..."
sudo docker run --rm --entrypoint "/usr/lib/plexmediaserver/Plex SQLite" \
  -v /opt/docker/appdata/plex:/config \
  lscr.io/linuxserver/plex:latest "$DB_CONTAINER" "
BEGIN TRANSACTION;

-- 1. Consolidate Film 2 (loc 32 -> 24) and TV 2 (loc 31 -> 26) in media_items
UPDATE media_items SET section_location_id = 24 WHERE section_location_id = 32;
UPDATE media_items SET section_location_id = 26 WHERE section_location_id = 31;
DELETE FROM section_locations WHERE id IN (31, 32);

-- 2. Update section_locations root_path to Linux container paths
UPDATE section_locations SET root_path = '/data/media/Films' WHERE id = 24;
UPDATE section_locations SET root_path = '/data/media/TV' WHERE id = 26;
UPDATE section_locations SET root_path = '/data/media/Audio' WHERE id = 27;
UPDATE section_locations SET root_path = '/data/vault/Photos/Finished Years' WHERE id = 28;
UPDATE section_locations SET root_path = '/data/media/Music' WHERE id = 29;
UPDATE section_locations SET root_path = '/data/media/Anime' WHERE id = 30;

-- 3. Update media_parts.file from Windows D:\ and E:\ (or /data/vault/{Music,Audio}) to Linux /data/media/...
UPDATE media_parts SET file = REPLACE(REPLACE(file, 'D:\Media\Films\', '/data/media/Films/'), '\', '/') WHERE file LIKE 'D:\Media\Films\%';
UPDATE media_parts SET file = REPLACE(REPLACE(file, 'E:\Media\Film 2\', '/data/media/Films/'), '\', '/') WHERE file LIKE 'E:\Media\Film 2\%';
UPDATE media_parts SET file = REPLACE(REPLACE(file, 'D:\Media\TV\', '/data/media/TV/'), '\', '/') WHERE file LIKE 'D:\Media\TV\%';
UPDATE media_parts SET file = REPLACE(REPLACE(file, 'E:\Media\TV 2\', '/data/media/TV/'), '\', '/') WHERE file LIKE 'E:\Media\TV 2\%';
UPDATE media_parts SET file = REPLACE(REPLACE(file, 'E:\Media\Anime\', '/data/media/Anime/'), '\', '/') WHERE file LIKE 'E:\Media\Anime\%';
UPDATE media_parts SET file = REPLACE(REPLACE(file, 'D:\Media\Photos\Finished Years\', '/data/vault/Photos/Finished Years/'), '\', '/') WHERE file LIKE 'D:\Media\Photos\Finished Years\%';
UPDATE media_parts SET file = REPLACE(REPLACE(file, 'D:\Media\Music\', '/data/media/Music/'), '\', '/') WHERE file LIKE 'D:\Media\Music\%';
UPDATE media_parts SET file = REPLACE(REPLACE(file, 'D:\Media\Audio\', '/data/media/Audio/'), '\', '/') WHERE file LIKE 'D:\Media\Audio\%';
UPDATE media_parts SET file = REPLACE(file, '/data/vault/Music/', '/data/media/Music/') WHERE file LIKE '/data/vault/Music/%';
UPDATE media_parts SET file = REPLACE(file, '/data/vault/Audio/', '/data/media/Audio/') WHERE file LIKE '/data/vault/Audio/%';

-- 4. Update external subtitle URLs in media_streams
UPDATE media_streams SET url = REPLACE(REPLACE(url, 'file:///D:/Media/Films/', 'file:///data/media/Films/'), '\', '/') WHERE url LIKE 'file:///D:/Media/Films/%';
UPDATE media_streams SET url = REPLACE(REPLACE(url, 'file:///E:/Media/Film%202/', 'file:///data/media/Films/'), '\', '/') WHERE url LIKE 'file:///E:/Media/Film%202/%';
UPDATE media_streams SET url = REPLACE(REPLACE(url, 'file:///D:/Media/TV/', 'file:///data/media/TV/'), '\', '/') WHERE url LIKE 'file:///D:/Media/TV/%';
UPDATE media_streams SET url = REPLACE(REPLACE(url, 'file:///E:/Media/TV%202/', 'file:///data/media/TV/'), '\', '/') WHERE url LIKE 'file:///E:/Media/TV%202/%';
UPDATE media_streams SET url = REPLACE(REPLACE(url, 'file:///E:/Media/Anime/', 'file:///data/media/Anime/'), '\', '/') WHERE url LIKE 'file:///E:/Media/Anime/%';

-- 5. Normalize any remaining backslashes in directories.path
UPDATE directories SET path = REPLACE(path, '\', '/') WHERE path LIKE '%\%';

COMMIT;
"

sudo chown -R charlie:charlie "$DB_DIR"

echo "[3/4] Starting Plex container..."
sudo docker start plex
sleep 5

echo "[4/4] Verifying updated section_locations:"
sudo docker exec plex "/usr/lib/plexmediaserver/Plex SQLite" "$DB_CONTAINER" "
SELECT id, library_section_id, root_path FROM section_locations;
"
