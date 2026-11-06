#!/usr/bin/env python3
"""
qBittorrent Smart Seeding & Night-Boost Manager
1. Enforces Daytime (06:00-02:00) vs Nighttime (02:00-06:00) active torrent limits.
2. Enables 'dont_count_slow_torrents' so stalled torrents don't hog active upload slots.
3. Tracks TRUE active uploading time (only when state == 'uploading' and upspeed > 1 KB/s),
   ignoring stalledUP and queuedUP time, and stops torrents after 7 days (604,800s) of active upload
   or ratio >= 2.0.
"""
import json
import os
from datetime import datetime
import requests

QB_URL = "http://localhost:8080"
QB_USER = "admin"
QB_PASS = "kIUIsFqEg"
STATE_FILE = "/opt/docker/appdata/qbittorrent/active_seeding_tracker.json"
MAX_ACTIVE_SEED_SECONDS = 7 * 24 * 3600  # 7 days (604,800 seconds) of active uploading
INTERVAL_SECONDS = 60

DAY_LIMITS = {
    "max_active_uploads": 5,
    "max_active_downloads": 4,
    "max_active_torrents": 8,
}

NIGHT_LIMITS = {
    "max_active_uploads": 15,
    "max_active_downloads": 10,
    "max_active_torrents": 20,
}


def main():
    s = requests.Session()
    r = s.post(
        f"{QB_URL}/api/v2/auth/login",
        data={"username": QB_USER, "password": QB_PASS},
        timeout=10,
    )
    if r.status_code not in (200, 204):
        return

    now_hour = datetime.now().hour
    is_night = 2 <= now_hour < 6
    target = NIGHT_LIMITS if is_night else DAY_LIMITS

    prefs = s.get(f"{QB_URL}/api/v2/app/preferences", timeout=10).json()
    updates = {}

    for k, v in target.items():
        if prefs.get(k) != v:
            updates[k] = v

    desired_static = {
        "queueing_enabled": True,
        "dont_count_slow_torrents": True,
        "slow_torrent_ul_rate_threshold": 5,
        "slow_torrent_dl_rate_threshold": 5,
        "slow_torrent_inactive_timer": 60,
        "max_ratio_enabled": True,
        "max_ratio": 2.0,
        "max_ratio_act": 0,
        "max_seeding_time_enabled": False,
        "max_seeding_time": -1,
    }
    for k, v in desired_static.items():
        if prefs.get(k) != v:
            updates[k] = v

    if updates:
        s.post(
            f"{QB_URL}/api/v2/app/setPreferences",
            data={"json": json.dumps(updates)},
            timeout=10,
        )

    tracker = {}
    if os.path.exists(STATE_FILE):
        try:
            with open(STATE_FILE, "r") as f:
                tracker = json.load(f)
        except Exception:
            tracker = {}

    torrents = s.get(f"{QB_URL}/api/v2/torrents/info", timeout=10).json()
    current_hashes = set()
    to_stop = []

    for t in torrents:
        h = t["hash"]
        current_hashes.add(h)
        entry = tracker.get(h, {"name": t.get("name", ""), "active_seconds": 0})
        entry["name"] = t.get("name", "")

        state = t.get("state", "")
        upspeed = t.get("upspeed", 0)
        ratio = t.get("ratio", 0.0)

        # Only count time when actively uploading (> 1 KB/s), NOT stalledUP or queuedUP
        if state in ("uploading", "forcedUP") and upspeed >= 1024:
            entry["active_seconds"] = entry.get("active_seconds", 0) + INTERVAL_SECONDS

        tracker[h] = entry

        if state in ("uploading", "stalledUP", "queuedUP", "forcedUP"):
            if entry["active_seconds"] >= MAX_ACTIVE_SEED_SECONDS or ratio >= 2.0:
                to_stop.append(h)

    if to_stop:
        joined_hashes = "|".join(to_stop)
        res = s.post(
            f"{QB_URL}/api/v2/torrents/stop",
            data={"hashes": joined_hashes},
            timeout=10,
        )
        if res.status_code == 404:
            s.post(
                f"{QB_URL}/api/v2/torrents/pause",
                data={"hashes": joined_hashes},
                timeout=10,
            )

    tracker = {h: v for h, v in tracker.items() if h in current_hashes}

    os.makedirs(os.path.dirname(STATE_FILE), exist_ok=True)
    with open(STATE_FILE, "w") as f:
        json.dump(tracker, f, indent=2)


if __name__ == "__main__":
    main()
