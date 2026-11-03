#!/usr/bin/env python3
r"""
rotate-jellyfin-library-art.py

Rotates Jellyfin library card posters daily by randomly selecting images from:
  M:\media\Custom Art\Library -> /mnt/media/data/media/Custom Art/Library/
  ├── Anime/
  ├── Collections/
  ├── Films/
  └── TV/

Runs via cron (e.g. daily at midnight) and updates the Primary image for each
library using the Jellyfin REST API so that client cache tags are refreshed.
"""

import os
import sys
import json
import base64
import random
import mimetypes
import argparse
import urllib.request
import urllib.error
from datetime import datetime

# Configuration defaults
JELLYFIN_URL = os.environ.get("JELLYFIN_URL", "http://localhost:8096")
JELLYFIN_API_KEY = os.environ.get("JELLYFIN_API_KEY", "00193591f4bf4265b5914a3a8462f90d")
BASE_ART_DIR = os.environ.get("ART_BASE_DIR", "/mnt/media/data/media/Custom Art/Library")
STATE_FILE = os.environ.get("STATE_FILE", "/opt/docker/scripts/.last_rotated_art.json")

SUPPORTED_EXTS = {".jpg", ".jpeg", ".png", ".webp"}

LIBRARY_CONFIG = {
    "Anime": {
        "folder": "Anime",
        "library_name": "Anime",
        "fallback_id": "0c41907140d802bb58430fed7e2cd79e",
    },
    "Collections": {
        "folder": "Collections",
        "library_name": "Collections",
        "fallback_id": "9d7ad6afe9afa2dab1a2f6e00ad28fa6",
    },
    "Films": {
        "folder": "Films",
        "library_name": "Movies",  # Default Jellyfin name for Films library
        "fallback_id": "f137a2dd21bbc1b99aa5c0f6bf02a805",
    },
    "TV": {
        "folder": "TV",
        "library_name": "Shows",   # Default Jellyfin name for TV library
        "fallback_id": "a656b907eb3a73532e40e44b968d0225",
    },
}

def log(msg: str):
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    print(f"[{timestamp}] {msg}", flush=True)

def load_state() -> dict:
    if os.path.exists(STATE_FILE):
        try:
            with open(STATE_FILE, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception as e:
            log(f"Warning: Could not read state file ({e}), starting fresh.")
    return {}

def save_state(state: dict):
    try:
        os.makedirs(os.path.dirname(os.path.abspath(STATE_FILE)), exist_ok=True)
        with open(STATE_FILE, "w", encoding="utf-8") as f:
            json.dump(state, f, indent=2)
    except Exception as e:
        log(f"Warning: Could not save state file ({e})")

def fetch_virtual_folders() -> dict:
    """Fetch map of {library_name: ItemId} from Jellyfin API."""
    url = f"{JELLYFIN_URL}/Library/VirtualFolders?api_key={JELLYFIN_API_KEY}"
    req = urllib.request.Request(url, headers={"Accept": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            data = json.loads(resp.read().decode())
            id_map = {}
            for item in data:
                name = item.get("Name")
                item_id = item.get("ItemId")
                if name and item_id:
                    id_map[name.lower()] = item_id
            return id_map
    except Exception as e:
        log(f"Warning: Failed to fetch VirtualFolders from API ({e}), will use fallback Item IDs.")
        return {}

def get_images_in_folder(folder_path: str) -> list[str]:
    if not os.path.isdir(folder_path):
        return []
    valid = []
    for fname in os.listdir(folder_path):
        ext = os.path.splitext(fname)[1].lower()
        if ext in SUPPORTED_EXTS:
            valid.append(fname)
    return sorted(valid)

def upload_image(item_id: str, image_path: str) -> bool:
    """Upload base64-encoded image to Jellyfin Primary image endpoint."""
    ext = os.path.splitext(image_path)[1].lower()
    mime = mimetypes.guess_type(image_path)[0] or ("image/png" if ext == ".png" else "image/jpeg")

    with open(image_path, "rb") as f:
        b64_data = base64.b64encode(f.read())

    url = f"{JELLYFIN_URL}/Items/{item_id}/Images/Primary?api_key={JELLYFIN_API_KEY}"
    req = urllib.request.Request(url, data=b64_data, headers={"Content-Type": mime}, method="POST")

    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            return resp.status in (200, 204)
    except urllib.error.HTTPError as e:
        log(f"HTTP error {e.code} uploading {image_path}: {e.reason}")
        return False
    except Exception as e:
        log(f"Error uploading {image_path}: {e}")
        return False

def rotate_libraries(dry_run: bool = False):
    log("=== Starting Jellyfin Library Art Rotation ===")
    virtual_folders = fetch_virtual_folders()
    state = load_state()
    updated = False

    for key, cfg in LIBRARY_CONFIG.items():
        folder_dir = os.path.join(BASE_ART_DIR, cfg["folder"])
        images = get_images_in_folder(folder_dir)

        if not images:
            log(f"[{key}] No images found in {folder_dir}. Skipping.")
            continue

        # Avoid picking the same image as yesterday if multiple choices exist
        last_image = state.get(key)
        candidate_images = [img for img in images if img != last_image] if len(images) > 1 else images
        chosen_image = random.choice(candidate_images)
        chosen_path = os.path.join(folder_dir, chosen_image)

        # Resolve ItemId dynamically or fallback
        lib_name = cfg["library_name"]
        item_id = virtual_folders.get(lib_name.lower()) or cfg["fallback_id"]

        if dry_run:
            log(f"[{key}] [DRY RUN] Would update to '{chosen_image}' (ItemId: {item_id})")
            continue

        log(f"[{key}] Updating library card to '{chosen_image}'...")
        if upload_image(item_id, chosen_path):
            state[key] = chosen_image
            updated = True
            log(f"[{key}] Successfully updated!")
        else:
            log(f"[{key}] Failed to update art.")

    if updated and not dry_run:
        save_state(state)

    log("=== Library Art Rotation Complete ===")

def main():
    parser = argparse.ArgumentParser(description="Rotate Jellyfin library posters daily.")
    parser.add_argument("--dry-run", action="store_true", help="Simulate rotation without updating Jellyfin")
    args = parser.parse_args()

    rotate_libraries(dry_run=args.dry_run)

if __name__ == "__main__":
    main()
