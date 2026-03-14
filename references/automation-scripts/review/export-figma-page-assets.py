#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path
from typing import Iterable
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen


DEFAULT_FILE_KEY = "ZhysC3KZLAmKerfHTpg3G6"
DEFAULT_NODE_TYPES = ("FRAME", "SECTION", "COMPONENT_SET", "COMPONENT")


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
        description="Bulk-export Figma page nodes to local images with API + Playwright fallback.",
    )
    parser.add_argument(
        "--project-root",
        default=os.environ.get(
            "ZZIRIT_IOS_PROJECT_ROOT",
            str(Path(__file__).resolve().parents[2]),
        ),
    )
    parser.add_argument(
        "--design-file",
        default="artifacts/figma-api/design-file.json",
        help="Path to a local Figma file JSON relative to project root unless absolute.",
    )
    parser.add_argument(
        "--page-name",
        default="",
        help="Exact page name to export. Defaults to latest page by index.",
    )
    parser.add_argument(
        "--page-index",
        type=int,
        default=None,
        help="Optional page index override when page-name is not provided.",
    )
    parser.add_argument(
        "--types",
        default=",".join(DEFAULT_NODE_TYPES),
        help="Comma-separated Figma node types to export.",
    )
    parser.add_argument(
        "--root-node-id",
        default="",
        help="Optional subtree root node id inside the selected page.",
    )
    parser.add_argument(
        "--root-node-name",
        default="",
        help="Optional subtree root node name inside the selected page when node id is not provided.",
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=0,
        help="Optional max node count for dry runs.",
    )
    parser.add_argument(
        "--max-depth",
        type=int,
        default=1,
        help="Max depth relative to the selected page. Defaults to 1 (top-level page children). Use 0 for page root only, negative for unlimited.",
    )
    parser.add_argument(
        "--sleep-ms",
        type=int,
        default=250,
        help="Delay between items to reduce request bursts.",
    )
    parser.add_argument(
        "--playwright-only",
        action="store_true",
        help="Skip API image download and use Playwright for every item.",
    )
    parser.add_argument(
        "--api-only",
        action="store_true",
        help="Skip Playwright fallback and use API only.",
    )
    return parser.parse_args()


def resolve_path(project_root: Path, raw_path: str) -> Path:
    path = Path(raw_path)
    return path if path.is_absolute() else project_root / path


def fetch_design_file(file_key: str, api_key: str) -> dict | None:
    if not api_key:
        return None
    request = Request(
        f"https://api.figma.com/v1/files/{file_key}",
        headers={"X-Figma-Token": api_key},
    )
    try:
        with urlopen(request, timeout=90) as response:
            return json.loads(response.read().decode("utf-8"))
    except (HTTPError, URLError):
        return None


def load_design_payload(project_root: Path, design_file: Path, file_key: str, api_key: str) -> tuple[dict, str]:
    if design_file.exists():
        return json.loads(design_file.read_text(encoding="utf-8")), "local-json"
    payload = fetch_design_file(file_key, api_key)
    if payload is None:
        raise SystemExit(
            f"Could not load design payload. Missing {design_file} and API fetch failed.",
        )
    design_file.parent.mkdir(parents=True, exist_ok=True)
    design_file.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return payload, "api-fetch"


def date_like_page_key(page: dict) -> tuple[int, int, str]:
    name = str(page.get("name", "")).strip()
    if re.fullmatch(r"\d{6}", name):
        return (1, int(name), name)
    return (0, -1, name)


def select_page(document: dict, page_name: str, page_index: int | None) -> dict:
    pages = document.get("children", []) or []
    if not pages:
        raise SystemExit("Figma document has no pages.")
    if page_name:
        for page in pages:
            if page.get("name") == page_name:
                return page
        raise SystemExit(f"Page not found: {page_name}")
    if page_index is not None:
        try:
            return pages[page_index]
        except IndexError as exc:
            raise SystemExit(f"Page index out of range: {page_index}") from exc

    date_pages = [page for page in pages if date_like_page_key(page)[0] == 1]
    if date_pages:
        return max(date_pages, key=date_like_page_key)
    return pages[0]


def collect_nodes(
    node: dict,
    types: set[str],
    trail: tuple[str, ...] = (),
    depth: int = 0,
    max_depth: int = -1,
) -> list[dict]:
    current_trail = trail + (node.get("name", "unnamed"),)
    rows: list[dict] = []
    node_type = node.get("type", "")
    node_id = node.get("id", "")
    within_depth = max_depth < 0 or depth <= max_depth
    if within_depth and node_type in types and node_id:
        rows.append(
            {
                "id": node_id,
                "type": node_type,
                "name": node.get("name", ""),
                "trail": current_trail,
                "depth": depth,
            },
        )
    if max_depth >= 0 and depth >= max_depth:
        return rows
    for child in node.get("children", []) or []:
        rows.extend(
            collect_nodes(
                child,
                types,
                current_trail,
                depth=depth + 1,
                max_depth=max_depth,
            ),
        )
    return rows


def find_node(node: dict, node_id: str = "", node_name: str = "") -> dict | None:
    if node_id and node.get("id") == node_id:
        return node
    if not node_id and node_name and node.get("name") == node_name:
        return node
    for child in node.get("children", []) or []:
        match = find_node(child, node_id=node_id, node_name=node_name)
        if match is not None:
            return match
    return None


def download_via_api(file_key: str, api_key: str, node_id: str, output_path: Path) -> tuple[bool, str]:
    if not api_key:
        return False, "api-key-missing"
    api_json_path = output_path.parent / f"{safe_node_id(node_id)}.api.json"
    try:
        request = Request(
            f"https://api.figma.com/v1/images/{file_key}?ids={node_id}&format=png&scale=2",
            headers={"X-Figma-Token": api_key},
        )
        with urlopen(request, timeout=90) as response:
            payload = json.loads(response.read().decode("utf-8"))
    except HTTPError as exc:
        return False, f"http-{exc.code}"
    except URLError as exc:
        return False, f"network-{exc.reason}"

    api_json_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    image_url = (payload.get("images") or {}).get(node_id, "")
    if not image_url:
        return False, "api-no-image-url"

    try:
        with urlopen(image_url, timeout=90) as response:
            output_path.write_bytes(response.read())
    except (HTTPError, URLError) as exc:
        return False, f"download-failed-{exc}"
    return True, "api"


def download_via_playwright(
    project_root: Path,
    file_key: str,
    node_id: str,
    output_path: Path,
    screen_key: str,
    run_dir: Path,
) -> tuple[bool, str]:
    script = project_root / "scripts" / "review" / "fetch-figma-playwright.sh"
    env = os.environ.copy()
    env["FIGMA_FILE_KEY"] = file_key
    env["FIGMA_NODE_ID"] = node_id
    env["ZZIRIT_FIGMA_SCREEN_KEY"] = screen_key
    env["FIGMA_OUTPUT_PATH"] = str(output_path)
    env["ZZIRIT_FIGMA_PLAYWRIGHT_RUN_DIR"] = str(run_dir)
    result = subprocess.run(
        ["bash", str(script)],
        cwd=project_root,
        env=env,
        capture_output=True,
        text=True,
    )
    if result.returncode == 0 and output_path.exists():
        return True, "playwright"
    return False, f"playwright-failed-{result.returncode}"


def write_summary(summary_path: Path, lines: Iterable[str]) -> None:
    summary_path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    args = parse_args()
    project_root = Path(args.project_root).resolve()
    load_env_file(Path.home() / ".zzirit-automation.env")

    file_key = os.environ.get("FIGMA_FILE_KEY", DEFAULT_FILE_KEY)
    api_key = os.environ.get("FIGMA_API_KEY", "")
    design_file = resolve_path(project_root, args.design_file)
    payload, payload_source = load_design_payload(project_root, design_file, file_key, api_key)

    types = {item.strip().upper() for item in args.types.split(",") if item.strip()}
    page = select_page(payload.get("document", {}), args.page_name, args.page_index)
    root_node = page
    if args.root_node_id or args.root_node_name:
        root_node = find_node(
            page,
            node_id=args.root_node_id.strip(),
            node_name=args.root_node_name.strip(),
        )
        if root_node is None:
            needle = args.root_node_id.strip() or args.root_node_name.strip()
            raise SystemExit(f"Root node not found inside page {page.get('name', '')}: {needle}")

    all_nodes = collect_nodes(root_node, types, depth=0, max_depth=args.max_depth)
    if args.limit > 0:
        all_nodes = all_nodes[: args.limit]

    timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    page_slug = slugify(page.get("name", "page"))
    run_dir = project_root / "artifacts" / "figma-page-export" / timestamp / page_slug
    run_dir.mkdir(parents=True, exist_ok=True)
    manifest_path = run_dir / "manifest.json"
    summary_path = run_dir / "summary.md"

    results: list[dict] = []
    for index, item in enumerate(all_nodes, start=1):
        node_slug = slugify(item["name"])
        type_slug = item["type"].lower()
        item_dir = run_dir / type_slug
        item_dir.mkdir(parents=True, exist_ok=True)
        output_path = item_dir / f"{index:04d}-{node_slug}-{safe_node_id(item['id'])}.png"
        screen_key = f"{page_slug}-{type_slug}-{index:04d}-{node_slug}"

        source = "missing"
        reason = ""
        if not args.playwright_only:
            ok, reason = download_via_api(file_key, api_key, item["id"], output_path)
            if ok:
                source = "api"
        if source == "missing" and not args.api_only:
            ok, pw_reason = download_via_playwright(
                project_root=project_root,
                file_key=file_key,
                node_id=item["id"],
                output_path=output_path,
                screen_key=screen_key,
                run_dir=run_dir / "playwright" / f"{index:04d}-{node_slug}",
            )
            reason = pw_reason if not reason else f"{reason},{pw_reason}"
            if ok:
                source = "playwright"

        results.append(
            {
                "index": index,
                "id": item["id"],
                "type": item["type"],
                "name": item["name"],
                "trail": item["trail"],
                "output_path": str(output_path),
                "exists": output_path.exists(),
                "source": source,
                "reason": reason,
                "depth": item["depth"],
            },
        )
        if args.sleep_ms > 0 and index < len(all_nodes):
            time.sleep(args.sleep_ms / 1000)

    manifest_path.write_text(json.dumps(results, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    success_count = sum(1 for item in results if item["exists"])
    lines = [
        "# Figma Page Asset Export",
        "",
        f"- file_key: {file_key}",
        f"- payload_source: {payload_source}",
        f"- design_file: {design_file}",
        f"- page_name: {page.get('name', '')}",
        f"- page_id: {page.get('id', '')}",
        f"- root_node_name: {root_node.get('name', '')}",
        f"- root_node_id: {root_node.get('id', '')}",
        f"- node_types: {', '.join(sorted(types))}",
        f"- max_depth: {args.max_depth}",
        f"- total_nodes: {len(results)}",
        f"- exported_images: {success_count}",
        f"- run_dir: {run_dir}",
        f"- manifest: {manifest_path}",
        "",
        "## Items",
        "",
    ]
    for item in results:
        status = "ok" if item["exists"] else "missing"
        lines.append(
            f"- [{status}] depth={item['depth']} {item['type']} `{item['id']}` {item['name']} -> {item['output_path']} "
            f"[source={item['source']} reason={item['reason']}]",
        )
    write_summary(summary_path, lines)
    print(summary_path)
    return 0


if __name__ == "__main__":
    sys.exit(main())
