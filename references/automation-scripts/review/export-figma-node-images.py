#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import re
import time
from datetime import datetime
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode
from urllib.request import Request, urlopen


DEFAULT_FILE_KEY = "ZhysC3KZLAmKerfHTpg3G6"


def load_env_file(path: Path) -> None:
    if not path.exists():
        return
    for line in path.read_text(encoding="utf-8").splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("#") or "=" not in stripped:
            continue
        key, value = stripped.split("=", 1)
        os.environ.setdefault(key.strip(), value.strip())


def slugify(value: str) -> str:
    value = re.sub(r"[^\w\s.-]", "", value, flags=re.UNICODE).strip().lower()
    value = re.sub(r"[\s./]+", "-", value)
    value = re.sub(r"-{2,}", "-", value)
    return value or "unnamed"


def safe_node_id(node_id: str) -> str:
    return node_id.replace(":", "-")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Export exact Figma node images via Figma Images API.",
    )
    parser.add_argument(
        "--project-root",
        default=str(Path(__file__).resolve().parents[2]),
        help="Repo root used for default output locations.",
    )
    parser.add_argument(
        "--item",
        action="append",
        default=[],
        help="Export item in label=node-id form. Can be repeated.",
    )
    parser.add_argument(
        "--output-dir",
        default="",
        help="Optional output directory. Defaults to artifacts/figma-exact-export/<timestamp>.",
    )
    parser.add_argument(
        "--scale",
        type=int,
        default=2,
        help="Figma image scale. Defaults to 2.",
    )
    return parser.parse_args()


def parse_item(raw_item: str) -> tuple[str, str]:
    if "=" not in raw_item:
        raise SystemExit(f"Invalid --item value: {raw_item}. Use label=node-id.")
    label, node_id = raw_item.split("=", 1)
    label = label.strip()
    node_id = node_id.strip()
    if not label or not node_id:
        raise SystemExit(f"Invalid --item value: {raw_item}. Use label=node-id.")
    return label, node_id


def download_binary(url: str) -> bytes:
    with urlopen(url, timeout=90) as response:
        return response.read()


def fetch_image_urls(file_key: str, api_key: str, node_ids: list[str], scale: int) -> dict:
    query = urlencode(
        {
            "ids": ",".join(node_ids),
            "format": "png",
            "scale": str(scale),
        },
    )
    request = Request(
        f"https://api.figma.com/v1/images/{file_key}?{query}",
        headers={"X-Figma-Token": api_key},
    )
    retry_delays = [5, 15, 30]
    attempt = 0
    while True:
        try:
            with urlopen(request, timeout=90) as response:
                return json.loads(response.read().decode("utf-8"))
        except HTTPError as exc:
            if exc.code == 429 and attempt < len(retry_delays):
                time.sleep(retry_delays[attempt])
                attempt += 1
                continue
            raise


def main() -> int:
    args = parse_args()
    project_root = Path(args.project_root).resolve()
    load_env_file(Path.home() / ".zzirit-automation.env")

    file_key = os.environ.get("FIGMA_FILE_KEY", DEFAULT_FILE_KEY)
    api_key = os.environ.get("FIGMA_API_KEY", "")
    if not api_key:
        raise SystemExit("FIGMA_API_KEY is required.")
    if not args.item:
        raise SystemExit("At least one --item label=node-id is required.")

    timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    output_dir = (
        Path(args.output_dir).resolve()
        if args.output_dir
        else project_root / "artifacts" / "figma-exact-export" / timestamp
    )
    output_dir.mkdir(parents=True, exist_ok=True)

    summary_lines = [
        "# Figma Exact Node Export",
        "",
        f"- file_key: {file_key}",
        f"- output_dir: {output_dir}",
        f"- scale: {args.scale}",
        "",
        "## Items",
        "",
    ]

    items = [parse_item(raw_item) for raw_item in args.item]
    batch_payload_path = output_dir / "batch.api.json"
    try:
        batch_payload = fetch_image_urls(
            file_key,
            api_key,
            [node_id for _, node_id in items],
            args.scale,
        )
        batch_payload_path.write_text(
            json.dumps(batch_payload, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
    except HTTPError as exc:
        summary_lines.append(f"- [error] batch -> http-{exc.code}")
        summary_path = output_dir / "summary.md"
        summary_path.write_text("\n".join(summary_lines) + "\n", encoding="utf-8")
        print(summary_path)
        return 0
    except URLError as exc:
        summary_lines.append(f"- [error] batch -> network-{exc.reason}")
        summary_path = output_dir / "summary.md"
        summary_path.write_text("\n".join(summary_lines) + "\n", encoding="utf-8")
        print(summary_path)
        return 0

    image_map = batch_payload.get("images") or {}
    for label, node_id in items:
        label_slug = slugify(label)
        safe_id = safe_node_id(node_id)
        png_path = output_dir / f"{label_slug}-{safe_id}.png"

        try:
            image_url = image_map.get(node_id, "")
            if not image_url:
                summary_lines.append(f"- [missing] `{node_id}` {label} -> no image URL")
                continue
            png_path.write_bytes(download_binary(image_url))
            summary_lines.append(f"- [ok] `{node_id}` {label} -> {png_path}")
        except HTTPError as exc:
            summary_lines.append(f"- [error] `{node_id}` {label} -> http-{exc.code}")
        except URLError as exc:
            summary_lines.append(f"- [error] `{node_id}` {label} -> network-{exc.reason}")

    summary_path = output_dir / "summary.md"
    summary_path.write_text("\n".join(summary_lines) + "\n", encoding="utf-8")
    print(summary_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
