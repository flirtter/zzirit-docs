#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


DEFAULT_ROOTS = [
    ("lightning", "20111:6607"),
    ("meeting", "20111:6617"),
    ("chat", "20117:7403"),
    ("my", "20114:7539"),
]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Extract reusable image-asset candidates from the Figma design JSON.",
    )
    parser.add_argument(
        "--design-file",
        default="/Users/user/zzirit-v2/artifacts/figma-api/design-file.json",
    )
    parser.add_argument(
        "--output-json",
        default="/Users/user/zzirit-v2/artifacts/figma-reference/catalog/assets-manifest.json",
    )
    parser.add_argument(
        "--output-md",
        default="/Users/user/zzirit-v2/artifacts/figma-reference/catalog/assets-catalog.md",
    )
    parser.add_argument(
        "--roots",
        nargs="*",
        help="Optional root definitions in alias=node_id form.",
    )
    parser.add_argument("--top-per-section", type=int, default=24)
    return parser.parse_args()


def build_index(document: dict[str, Any]) -> tuple[dict[str, dict[str, Any]], dict[str, str]]:
    index: dict[str, dict[str, Any]] = {}
    parent: dict[str, str] = {}
    stack = [document]
    while stack:
        node = stack.pop()
        node_id = node.get("id")
        if node_id:
            index[node_id] = node
        for child in node.get("children", []):
            if child.get("id"):
                parent[child["id"]] = node_id
            stack.append(child)
    return index, parent


def parse_roots(raw_roots: list[str] | None) -> list[tuple[str, str]]:
    if not raw_roots:
        return DEFAULT_ROOTS
    roots: list[tuple[str, str]] = []
    for item in raw_roots:
        if "=" not in item:
            raise SystemExit(f"Invalid root definition: {item}")
        alias, node_id = item.split("=", 1)
        roots.append((alias.strip(), node_id.strip()))
    return roots


def node_path(node_id: str, index: dict[str, dict[str, Any]], parent: dict[str, str], stop_id: str) -> list[str]:
    parts: list[str] = []
    current = node_id
    while current and current in index:
        node = index[current]
        parts.append(f"{node.get('name', '')} ({current})")
        if current == stop_id:
            break
        current = parent.get(current, "")
    parts.reverse()
    return parts


def collect_image_fills(node: dict[str, Any]) -> list[dict[str, Any]]:
    fills: list[dict[str, Any]] = []
    for key in ("fills", "background"):
        value = node.get(key) or []
        if isinstance(value, list):
            fills.extend(v for v in value if isinstance(v, dict) and v.get("type") == "IMAGE")
    return fills


def classify_candidate(name: str, width: float, height: float, path_text: str) -> str:
    lowered = f"{name} {path_text}".lower()
    longest = max(width, height)
    shortest = min(width, height)
    if "map" in lowered:
        return "map"
    if ("avatar" in lowered or "profile" in lowered) and longest <= 120:
        return "avatar"
    if "card" in lowered:
        return "card-image"
    if longest >= 300 and shortest >= 300:
        return "hero-image"
    if longest <= 120 and shortest <= 120:
        return "small-avatar"
    return "image-fill"


def candidate_priority(category: str, width: float, height: float) -> str:
    area = width * height
    if category in {"hero-image", "card-image", "map"} or area >= 40000:
        return "high"
    if category in {"avatar", "small-avatar"} or area >= 5000:
        return "medium"
    return "low"


def collect_descendants(root: dict[str, Any]) -> list[dict[str, Any]]:
    result: list[dict[str, Any]] = []
    stack = [root]
    while stack:
        node = stack.pop()
        if node.get("id") != root.get("id"):
            result.append(node)
        children = node.get("children", [])
        stack.extend(reversed(children))
    return result


def main() -> int:
    args = parse_args()
    design_file = Path(args.design_file)
    output_json = Path(args.output_json)
    output_md = Path(args.output_md)

    with design_file.open() as f:
        data = json.load(f)

    index, parent = build_index(data["document"])
    roots = parse_roots(args.roots)

    sections: list[dict[str, Any]] = []
    for alias, root_id in roots:
        if root_id not in index:
            continue
        root = index[root_id]
        groups: dict[str, dict[str, Any]] = {}
        total_nodes = 0
        for node in collect_descendants(root):
            total_nodes += 1
            image_fills = collect_image_fills(node)
            if not image_fills:
                continue
            bb = node.get("absoluteBoundingBox") or {}
            width = float(bb.get("width") or 0)
            height = float(bb.get("height") or 0)
            refs = sorted({fill.get("imageRef", "") for fill in image_fills if fill.get("imageRef")})
            if not refs:
                continue
            ref_key = "|".join(refs)
            path_items = node_path(node["id"], index, parent, root_id)
            path_text = " > ".join(path_items)
            category = classify_candidate(node.get("name", ""), width, height, path_text)
            priority = candidate_priority(category, width, height)
            candidate = {
                "node_id": node["id"],
                "name": node.get("name", ""),
                "type": node.get("type", ""),
                "width": width,
                "height": height,
                "area": width * height,
                "image_refs": refs,
                "image_fill_count": len(image_fills),
                "path": path_items,
                "category": category,
                "priority": priority,
                "capture_method": "node_export_preferred__cdp_crop_fallback",
                "capture_ready": True,
            }
            existing = groups.get(ref_key)
            if existing is None or candidate["area"] > existing["representative"]["area"]:
                groups[ref_key] = {
                    "image_ref_key": ref_key,
                    "occurrence_count": 1 if existing is None else existing["occurrence_count"] + 1,
                    "representative": candidate,
                }
            else:
                existing["occurrence_count"] += 1

        deduped = sorted(
            groups.values(),
            key=lambda item: (
                {"high": 0, "medium": 1, "low": 2}.get(item["representative"]["priority"], 9),
                -item["representative"]["area"],
                -item["occurrence_count"],
            ),
        )
        sections.append(
            {
                "alias": alias,
                "root_node_id": root_id,
                "root_name": root.get("name", ""),
                "root_type": root.get("type", ""),
                "descendant_nodes_scanned": total_nodes,
                "unique_image_assets": len(deduped),
                "candidates": deduped[: args.top_per_section],
            }
        )

    manifest = {
        "version": 1,
        "generated_on": "2026-03-11",
        "source_design_file": str(design_file),
        "file_key": data.get("key") or "ZhysC3KZLAmKerfHTpg3G6",
        "strategy": {
            "dedupe": "group by imageRef set, keep largest representative node",
            "preferred_export": "Figma node export",
            "fallback_export": "CDP screenshot plus selection crop",
        },
        "sections": sections,
    }

    output_json.parent.mkdir(parents=True, exist_ok=True)
    output_md.parent.mkdir(parents=True, exist_ok=True)
    output_json.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")

    lines = [
        "# Figma Asset Catalog",
        "",
        "This catalog lists reusable image-asset candidates discovered under the current tab sections.",
        "",
        "- preferred export: node export",
        "- fallback export: CDP screenshot plus selection crop",
        "- dedupe rule: same `imageRef` set is treated as the same asset; the largest node becomes the representative",
        "",
    ]
    for section in sections:
        lines.extend(
            [
                f"## {section['alias']}",
                "",
                f"- root: `{section['root_name']} ({section['root_node_id']})`",
                f"- descendant nodes scanned: `{section['descendant_nodes_scanned']}`",
                f"- unique image assets: `{section['unique_image_assets']}`",
                "",
            ]
        )
        for item in section["candidates"]:
            rep = item["representative"]
            lines.extend(
                [
                    f"- `{rep['priority']}` `{rep['category']}` `{rep['name'] or '<unnamed>'}` `{rep['node_id']}` `{int(rep['width'])}x{int(rep['height'])}` refs={len(rep['image_refs'])} used={item['occurrence_count']}",
                    f"  - path: `{' > '.join(rep['path'])}`",
                ]
            )
        lines.append("")
    output_md.write_text("\n".join(lines))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
