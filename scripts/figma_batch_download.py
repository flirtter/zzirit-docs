#!/usr/bin/env python3
"""
Figma batch image downloader.
Uses /v1/images endpoint to export multiple nodes per request.
~114 frames → ~8 API calls (instead of 114).
"""
import json
import os
import sys
import time
import urllib.request
import urllib.error
from pathlib import Path

API_KEY = os.environ.get("FIGMA_API_KEY", "")
DESIGN_FILE_KEY = "0KbCmyCo7m487adolGS3lW"
PLANNING_FILE_KEY = "VyUM039bpvrwupsXkNNCwW"
OUTPUT_DIR = Path(os.environ.get("OUTPUT_DIR", os.path.expanduser("~/zzirit-docs/references/figma-exports")))
BATCH_SIZE = 15  # nodes per API call
DELAY_BETWEEN_BATCHES = 3  # seconds

def figma_api(endpoint: str) -> dict:
    """Make a Figma API request."""
    url = f"https://api.figma.com/v1{endpoint}"
    req = urllib.request.Request(url, headers={"X-Figma-Token": API_KEY})
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            return json.loads(resp.read())
    except urllib.error.HTTPError as e:
        if e.code == 429:
            retry = int(e.headers.get("Retry-After", "30"))
            print(f"  Rate limited. Waiting {retry}s...")
            time.sleep(retry)
            return figma_api(endpoint)
        raise

def get_page_frames(file_key: str, page_id: str) -> list[dict]:
    """Get all top-level frames from a page."""
    data = figma_api(f"/files/{file_key}/nodes?ids={page_id}&depth=2")
    nodes = data.get("nodes", {})
    page_data = nodes.get(page_id, {}).get("document", {})
    children = page_data.get("children", [])
    frames = []
    for child in children:
        if child.get("type") in ("FRAME", "COMPONENT", "GROUP"):
            frames.append({
                "id": child["id"],
                "name": child.get("name", "unnamed"),
                "type": child.get("type"),
            })
    return frames

def export_images(file_key: str, node_ids: list[str], scale: float = 2.0, fmt: str = "png") -> dict:
    """Export multiple nodes as images in one API call. Returns {node_id: image_url}."""
    ids_param = ",".join(node_ids)
    data = figma_api(f"/images/{file_key}?ids={ids_param}&scale={scale}&format={fmt}")
    return data.get("images", {})

def download_image(url: str, path: Path):
    """Download an image from URL to local path."""
    path.parent.mkdir(parents=True, exist_ok=True)
    req = urllib.request.Request(url)
    with urllib.request.urlopen(req, timeout=60) as resp:
        path.write_bytes(resp.read())

def sanitize_name(name: str) -> str:
    """Sanitize filename."""
    return name.replace("/", "_").replace(" ", "_").replace(":", "").replace("?", "")[:80]

def categorize_frame(name: str) -> str:
    """Categorize a frame into a surface folder."""
    n = name.lower()
    if any(k in n for k in ["온보딩", "스플래시", "알림허용", "위치 허용", "위치허용"]):
        return "onboarding"
    if any(k in n for k in ["번개"]):
        return "lightning"
    if any(k in n for k in ["미팅", "미팅 -"]):
        return "meeting"
    if any(k in n for k in ["채팅"]):
        return "chat"
    if any(k in n for k in ["마이/like", "like"]):
        return "likes"
    if any(k in n for k in ["my", "my_", "마이"]):
        return "my"
    if any(k in n for k in ["로그인", "회원가입"]):
        return "login"
    return "misc"

def process_file(file_key: str, page_id: str, label: str):
    """Process one Figma file page: get frames, batch export, download."""
    print(f"\n{'='*60}")
    print(f"Processing: {label} (page {page_id})")
    print(f"{'='*60}")

    # Step 1: Get frames
    print("1. Fetching page frames...")
    frames = get_page_frames(file_key, page_id)
    print(f"   Found {len(frames)} frames")

    if not frames:
        print("   No frames found, skipping.")
        return

    # Step 2: Batch export
    node_ids = [f["id"] for f in frames]
    id_to_frame = {f["id"]: f for f in frames}
    all_images = {}

    batches = [node_ids[i:i+BATCH_SIZE] for i in range(0, len(node_ids), BATCH_SIZE)]
    print(f"2. Exporting images in {len(batches)} batches (batch_size={BATCH_SIZE})...")

    for i, batch in enumerate(batches):
        print(f"   Batch {i+1}/{len(batches)}: {len(batch)} nodes...", end=" ", flush=True)
        try:
            images = export_images(file_key, batch)
            all_images.update(images)
            print(f"OK ({len(images)} images)")
        except Exception as e:
            print(f"ERROR: {e}")
        if i < len(batches) - 1:
            time.sleep(DELAY_BETWEEN_BATCHES)

    # Step 3: Download
    print(f"3. Downloading {len(all_images)} images...")
    catalog = []
    for node_id, url in all_images.items():
        if not url:
            continue
        frame = id_to_frame.get(node_id, {"name": node_id})
        surface = categorize_frame(frame["name"])
        safe_name = sanitize_name(frame["name"])
        filename = f"{safe_name}_{node_id.replace(':', '-')}.png"
        dest = OUTPUT_DIR / label / surface / filename

        try:
            download_image(url, dest)
            catalog.append({
                "node_id": node_id,
                "name": frame["name"],
                "surface": surface,
                "path": str(dest.relative_to(OUTPUT_DIR)),
            })
            print(f"   ✓ {surface}/{filename}")
        except Exception as e:
            print(f"   ✗ {frame['name']}: {e}")

    # Save catalog
    catalog_path = OUTPUT_DIR / label / "catalog.json"
    catalog_path.write_text(json.dumps(catalog, indent=2, ensure_ascii=False) + "\n")
    print(f"\nDone: {len(catalog)} images saved. Catalog: {catalog_path}")

def main():
    if not API_KEY:
        print("ERROR: FIGMA_API_KEY not set")
        sys.exit(1)

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    print(f"Output: {OUTPUT_DIR}")

    # Design file - latest page (251219)
    process_file(DESIGN_FILE_KEY, "31:3248", "design-251219")

    time.sleep(5)  # extra delay between files

    # Design file - 251019 page
    process_file(DESIGN_FILE_KEY, "20220:16732", "design-251019")

    time.sleep(5)

    # Planning file
    process_file(PLANNING_FILE_KEY, "0:1", "planning")

    print(f"\n{'='*60}")
    print("All done!")
    print(f"Total output: {OUTPUT_DIR}")

if __name__ == "__main__":
    main()
