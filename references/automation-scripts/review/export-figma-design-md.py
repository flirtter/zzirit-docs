#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import sys
from datetime import datetime
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen


def load_env_file(path: Path) -> None:
    if not path.exists():
        return
    for line in path.read_text(encoding="utf-8").splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("#") or "=" not in stripped:
            continue
        key, value = stripped.split("=", 1)
        os.environ.setdefault(key.strip(), value.strip())


def flatten(node: dict, depth: int = 0, out: list[tuple[int, str, str, str]] | None = None):
    if out is None:
        out = []
    out.append((depth, node.get("id", ""), node.get("type", ""), node.get("name", "")))
    for child in node.get("children", []) or []:
        flatten(child, depth + 1, out)
    return out


def write_summary(path: Path, lines: list[str]) -> None:
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    root = Path(os.environ.get("ZZIRIT_IOS_PROJECT_ROOT", Path(__file__).resolve().parents[2]))
    load_env_file(Path.home() / ".zzirit-automation.env")
    file_key = os.environ.get("FIGMA_FILE_KEY", "ZhysC3KZLAmKerfHTpg3G6")
    api_key = os.environ.get("FIGMA_API_KEY", "")
    timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    run_dir = root / "artifacts" / "figma-api" / "full-export" / timestamp
    run_dir.mkdir(parents=True, exist_ok=True)
    summary_path = run_dir / "summary.md"
    output_json = run_dir / "design-file.json"
    output_md = root / "docs" / "spec" / "figma-design-catalog.md"

    if not api_key:
        write_summary(
            summary_path,
            [
                "# Figma Design Export",
                "",
                "- status: blocked",
                "- reason: FIGMA_API_KEY missing",
                f"- file_key: {file_key}",
            ],
        )
        print(summary_path)
        return 0

    request = Request(
        f"https://api.figma.com/v1/files/{file_key}",
        headers={"X-Figma-Token": api_key},
    )

    try:
        with urlopen(request, timeout=60) as response:
            raw = response.read().decode("utf-8")
    except HTTPError as exc:
        write_summary(
            summary_path,
            [
                "# Figma Design Export",
                "",
                "- status: blocked",
                f"- reason: http-{exc.code}",
                f"- file_key: {file_key}",
            ],
        )
        print(summary_path)
        return 0
    except URLError as exc:
        write_summary(
            summary_path,
            [
                "# Figma Design Export",
                "",
                "- status: blocked",
                f"- reason: network-error {exc.reason}",
                f"- file_key: {file_key}",
            ],
        )
        print(summary_path)
        return 0

    payload = json.loads(raw)
    output_json.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    flat = flatten(payload.get("document", {}))

    lines = [
        "# Figma Design Catalog",
        "",
        f"- file_key: {file_key}",
        f"- exported_at: {timestamp}",
        f"- source_json: {output_json}",
        "",
        "| Depth | Node ID | Type | Name |",
        "| --- | --- | --- | --- |",
    ]
    for depth, node_id, node_type, name in flat:
        indent = "&nbsp;" * (depth * 2)
        safe_name = str(name).replace("|", "\\|")
        lines.append(f"| {depth} | `{node_id}` | `{node_type}` | {indent}{safe_name} |")
    output_md.write_text("\n".join(lines) + "\n", encoding="utf-8")

    write_summary(
        summary_path,
        [
            "# Figma Design Export",
            "",
            "- status: exported",
            f"- file_key: {file_key}",
            f"- output_json: {output_json}",
            f"- output_md: {output_md}",
            f"- node_count: {len(flat)}",
        ],
    )
    print(summary_path)
    return 0


if __name__ == "__main__":
    sys.exit(main())
