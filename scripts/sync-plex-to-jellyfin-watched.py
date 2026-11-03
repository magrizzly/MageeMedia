#!/usr/bin/env python3
"""
MageeMedia 2.0 — Sync Watch History & Resume Positions from Plex SQLite DB to Jellyfin API
Matches items by exact container path (/data/media/...) and updates Jellyfin UserData via REST API.
"""

import sqlite3
import urllib.request
import json
from datetime import datetime, timezone
from concurrent.futures import ThreadPoolExecutor, as_completed

PLEX_DB = "/opt/docker/appdata/plex/Library/Application Support/Plex Media Server/Plug-in Support/Databases/com.plexapp.plugins.library.db"
JELLYFIN_DB = "/opt/docker/appdata/jellyfin/data/data/jellyfin.db"
JELLYFIN_URL = "http://127.0.0.1:8096"

# Mapping of Plex Account Name -> Jellyfin Username (case-insensitive match)
USER_MAP = {
    "Magrizzly": "magrizzly",
    "Magoober": "Harry",
    "lrwpotter": "Lewis",
    "emilyymagee": "Emily",
    "TV": "Linda",
    "countc3": "CountCasper",
}


def main():
    jf_conn = sqlite3.connect(JELLYFIN_DB)
    api_key_row = jf_conn.execute("SELECT AccessToken FROM ApiKeys LIMIT 1").fetchone()
    if not api_key_row:
        raise RuntimeError("No Jellyfin API key found in ApiKeys table.")
    api_key = api_key_row[0]

    # Load Jellyfin users (case-insensitive username -> Formatted GUID)
    jf_users = {}
    for uid, uname in jf_conn.execute("SELECT Id, Username FROM Users").fetchall():
        jf_users[uname.lower()] = (uid.lower().replace("-", ""), uid, uname)

    # Load Jellyfin BaseItems (file path -> ItemId without hyphens for REST API)
    jf_items = {}
    for item_id, path in jf_conn.execute("SELECT Id, Path FROM BaseItems WHERE Path IS NOT NULL").fetchall():
        jf_items[path] = item_id.lower().replace("-", "")

    print(f"Loaded {len(jf_items)} indexed media paths from Jellyfin.")

    plex_conn = sqlite3.connect(PLEX_DB)
    plex_accounts = {
        name: acc_id
        for acc_id, name in plex_conn.execute("SELECT id, name FROM accounts WHERE name != ''").fetchall()
    }

    headers = {
        "X-Emby-Token": api_key,
        "Content-Type": "application/json",
    }

    for plex_name, jf_target_name in USER_MAP.items():
        if plex_name not in plex_accounts:
            print(f"[WARN] Plex user '{plex_name}' not found in Plex database.")
            continue
        if jf_target_name.lower() not in jf_users:
            print(f"[WARN] Jellyfin user '{jf_target_name}' not found in Jellyfin database.")
            continue

        plex_acc_id = plex_accounts[plex_name]
        jf_uid_clean, jf_uid_raw, jf_uname = jf_users[jf_target_name.lower()]

        # Query watched or in-progress items from Plex
        rows = plex_conn.execute(
            """
            SELECT mp.file, MAX(COALESCE(s.view_count, 0)), MAX(COALESCE(s.view_offset, 0)), MAX(COALESCE(s.last_viewed_at, 0))
            FROM metadata_item_settings s
            JOIN metadata_items mi ON s.guid = mi.guid
            JOIN media_items m ON m.metadata_item_id = mi.id
            JOIN media_parts mp ON mp.media_item_id = m.id
            WHERE s.account_id = ? AND (s.view_count > 0 OR s.view_offset > 0)
            GROUP BY mp.file
            """,
            (plex_acc_id,),
        ).fetchall()

        tasks = []
        unmatched = 0
        for file_path, view_count, view_offset, last_viewed_at in rows:
            item_id = jf_items.get(file_path)
            if not item_id:
                unmatched += 1
                continue

            played = bool(view_count and view_count > 0)
            play_count = int(view_count) if played else 0
            # Plex view_offset is in milliseconds; Jellyfin PlaybackPositionTicks is 10,000 ticks per millisecond
            ticks = int(view_offset) * 10000 if view_offset and view_offset > 0 else 0

            payload = {
                "Played": played,
                "PlayCount": max(play_count, 1) if played else 0,
                "PlaybackPositionTicks": ticks,
            }
            if last_viewed_at and int(last_viewed_at) > 0:
                dt = datetime.fromtimestamp(int(last_viewed_at), tz=timezone.utc)
                payload["LastPlayedDate"] = dt.strftime("%Y-%m-%dT%H:%M:%SZ")

            tasks.append((item_id, payload))

        print(
            f"\nSyncing Plex user '{plex_name}' -> Jellyfin user '{jf_uname}': "
            f"{len(tasks)} matched items ({unmatched} not in Jellyfin library)..."
        )

        def update_item(task):
            item_id, payload = task
            url = f"{JELLYFIN_URL}/UserItems/{item_id}/UserData?userId={jf_uid_clean}"
            req = urllib.request.Request(
                url, data=json.dumps(payload).encode("utf-8"), headers=headers, method="POST"
            )
            with urllib.request.urlopen(req, timeout=15) as resp:
                return resp.status

        success = 0
        errors = 0
        with ThreadPoolExecutor(max_workers=16) as pool:
            futures = [pool.submit(update_item, t) for t in tasks]
            for f in as_completed(futures):
                try:
                    if f.result() == 200:
                        success += 1
                except Exception as e:
                    errors += 1

        print(f"  -> Completed '{jf_uname}': {success} synced, {errors} errors.")


if __name__ == "__main__":
    main()
