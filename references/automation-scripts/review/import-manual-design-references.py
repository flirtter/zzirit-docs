#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import shutil
from collections import defaultdict
from datetime import datetime
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Import manual design references from a local folder.")
    parser.add_argument(
        "--source-dir",
        default="/Users/user/Downloads/Design",
        help="Source directory containing section subdirectories with design images.",
    )
    parser.add_argument(
        "--output-root",
        default="/Users/user/zzirit-v2/artifacts/manual-design-references",
        help="Destination root for imported design reference bundles.",
    )
    return parser.parse_args()


def iter_source_files(source_dir: Path) -> list[Path]:
    return sorted(
        [
            path
            for path in source_dir.rglob("*")
            if path.is_file() and path.name != ".DS_Store"
        ],
        key=lambda path: path.relative_to(source_dir).as_posix().lower(),
    )


def build_signature(source_dir: Path, files: list[Path]) -> str:
    digest = hashlib.sha256()
    for file_path in files:
        stat = file_path.stat()
        rel = file_path.relative_to(source_dir).as_posix()
        digest.update(rel.encode("utf-8"))
        digest.update(str(stat.st_size).encode("utf-8"))
        digest.update(str(stat.st_mtime_ns).encode("utf-8"))
    return digest.hexdigest()


def load_latest_signature(latest_dir: Path) -> str | None:
    catalog_json = latest_dir / "catalog.json"
    if not catalog_json.exists():
        return None
    try:
        payload = json.loads(catalog_json.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return None
    return payload.get("signature")


def write_catalog(target_dir: Path, source_dir: Path, signature: str, sections: dict[str, list[str]]) -> None:
    catalog_json = {
        "imported_at": target_dir.name,
        "source": str(source_dir),
        "signature": signature,
        "sections": sections,
    }
    (target_dir / "catalog.json").write_text(
        json.dumps(catalog_json, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )

    lines = [
        "# Manual Design Reference Catalog",
        "",
        f"- imported_at: {target_dir.name}",
        f"- source: {source_dir}",
        f"- signature: {signature}",
        "",
    ]

    for section, items in sections.items():
        lines.append(f"## {section}")
        for relative_path in items:
            lines.append(f"- {Path(relative_path).name}: {target_dir / relative_path}")
        lines.append("")

    (target_dir / "catalog.md").write_text("\n".join(lines).rstrip() + "\n", encoding="utf-8")


def update_latest_symlink(output_root: Path, target_dir: Path) -> None:
    latest_link = output_root / "latest"
    if latest_link.exists() or latest_link.is_symlink():
        latest_link.unlink()
    latest_link.symlink_to(target_dir, target_is_directory=True)


def main() -> int:
    args = parse_args()
    source_dir = Path(args.source_dir).expanduser().resolve()
    output_root = Path(args.output_root).expanduser().resolve()
    output_root.mkdir(parents=True, exist_ok=True)
    latest_link = output_root / "latest"
    latest_dir = latest_link.resolve() if latest_link.exists() else None

    if not source_dir.exists():
        if latest_dir and latest_dir.exists():
            print(
                json.dumps(
                    {
                        "status": "reused-existing-latest",
                        "source": str(source_dir),
                        "latest": str(latest_dir),
                        "signature": load_latest_signature(latest_dir),
                    }
                )
            )
            return 0
        print(json.dumps({"status": "missing-source", "source": str(source_dir)}))
        return 0

    files = iter_source_files(source_dir)
    if not files:
        if latest_dir and latest_dir.exists():
            print(
                json.dumps(
                    {
                        "status": "reused-existing-latest",
                        "source": str(source_dir),
                        "latest": str(latest_dir),
                        "signature": load_latest_signature(latest_dir),
                    }
                )
            )
            return 0
        print(json.dumps({"status": "empty-source", "source": str(source_dir)}))
        return 0

    signature = build_signature(source_dir, files)
    if latest_dir and latest_dir.exists():
        latest_signature = load_latest_signature(latest_dir)
        if latest_signature == signature:
            print(
                json.dumps(
                    {
                        "status": "reused",
                        "latest": str(latest_dir),
                        "signature": signature,
                    }
                )
            )
            return 0

    timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    target_dir = output_root / timestamp
    target_dir.mkdir(parents=True, exist_ok=False)

    sections: dict[str, list[str]] = defaultdict(list)
    for file_path in files:
        rel_path = file_path.relative_to(source_dir)
        section = rel_path.parts[0]
        sections[section].append(rel_path.as_posix())

        destination = target_dir / rel_path
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(file_path, destination)

    ordered_sections = {section: sections[section] for section in sorted(sections.keys(), key=str.lower)}
    write_catalog(target_dir, source_dir, signature, ordered_sections)
    update_latest_symlink(output_root, target_dir)

    print(
        json.dumps(
            {
                "status": "imported",
                "target": str(target_dir),
                "latest": str((output_root / "latest").resolve()),
                "signature": signature,
                "section_count": len(ordered_sections),
                "file_count": len(files),
            }
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
