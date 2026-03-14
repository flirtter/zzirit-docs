#!/usr/bin/env python3
from __future__ import annotations

import json
import shutil
from pathlib import Path
from typing import Iterable


HUB_ROOT = Path("/Users/user/zzirit-memory-hub")
V2_ROOT = Path("/Users/user/zzirit-v2")
DOWNLOADS_DESIGN = Path("/Users/user/Downloads/Design")

SOURCE_SURFACE_SPECS = V2_ROOT / "docs/spec/surfaces"
SOURCE_MANUAL_DESIGN = V2_ROOT / "artifacts/manual-design-references/latest"

DEST_REFERENCES = HUB_ROOT / "references"
DEST_SURFACE_SPECS = DEST_REFERENCES / "surface-specs"
DEST_MANUAL_DESIGN = DEST_REFERENCES / "manual-design"
DEST_DESIGN_DOWNLOADS = DEST_MANUAL_DESIGN / "downloads-design"
DEST_DESIGN_BUNDLE = DEST_MANUAL_DESIGN / "bundle-latest"
DEST_INDEX = DEST_REFERENCES / "README.md"
DEST_INDEX_JSON = DEST_REFERENCES / "index.json"


def reset_dir(path: Path) -> None:
    if path.exists() or path.is_symlink():
        if path.is_dir() and not path.is_symlink():
            shutil.rmtree(path)
        else:
            path.unlink()
    path.mkdir(parents=True, exist_ok=True)


def copy_tree(src: Path, dst: Path) -> None:
    if not src.exists():
        return
    if src.is_symlink():
        src = src.resolve()
    for item in src.rglob("*"):
        rel = item.relative_to(src)
        target = dst / rel
        if item.is_dir():
            target.mkdir(parents=True, exist_ok=True)
            continue
        if item.name == ".DS_Store":
            continue
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(item, target)


def list_files(root: Path) -> list[str]:
    if not root.exists():
        return []
    files = []
    for item in sorted(root.rglob("*")):
        if item.is_file():
            files.append(str(item.relative_to(HUB_ROOT)))
    return files


def render_index(spec_files: Iterable[str], design_files: Iterable[str], bundle_files: Iterable[str]) -> str:
    lines = [
        "# Reference Context",
        "",
        "이 디렉터리는 허브만 봐도 surface별 컨텍스트를 다시 구성할 수 있도록 사양과 디자인 원본을 복제한 것이다.",
        "",
        "## Included",
        "",
        "- `surface-specs/`: `zzirit-v2/docs/spec/surfaces` 사본",
        "- `manual-design/bundle-latest/`: `zzirit-v2/artifacts/manual-design-references/latest` 사본",
        "- `manual-design/downloads-design/`: `/Users/user/Downloads/Design` 사본",
        "",
        "## Surface Spec Files",
    ]
    for item in spec_files:
        lines.append(f"- `{item}`")
    lines.extend([
        "",
        "## Manual Design Bundle Files",
    ])
    for item in bundle_files:
        lines.append(f"- `{item}`")
    lines.extend([
        "",
        "## Downloads Design Files",
    ])
    for item in design_files:
        lines.append(f"- `{item}`")
    lines.append("")
    return "\n".join(lines)


def main() -> int:
    DEST_REFERENCES.mkdir(parents=True, exist_ok=True)
    reset_dir(DEST_SURFACE_SPECS)
    reset_dir(DEST_DESIGN_BUNDLE)
    reset_dir(DEST_DESIGN_DOWNLOADS)

    copy_tree(SOURCE_SURFACE_SPECS, DEST_SURFACE_SPECS)
    copy_tree(SOURCE_MANUAL_DESIGN, DEST_DESIGN_BUNDLE)
    copy_tree(DOWNLOADS_DESIGN, DEST_DESIGN_DOWNLOADS)

    spec_files = list_files(DEST_SURFACE_SPECS)
    bundle_files = list_files(DEST_DESIGN_BUNDLE)
    design_files = list_files(DEST_DESIGN_DOWNLOADS)

    payload = {
        "surface_specs_source": str(SOURCE_SURFACE_SPECS),
        "manual_design_bundle_source": str(SOURCE_MANUAL_DESIGN.resolve()) if SOURCE_MANUAL_DESIGN.exists() else str(SOURCE_MANUAL_DESIGN),
        "downloads_design_source": str(DOWNLOADS_DESIGN),
        "spec_files": spec_files,
        "bundle_files": bundle_files,
        "downloads_design_files": design_files,
    }
    DEST_INDEX.write_text(render_index(spec_files, design_files, bundle_files), encoding="utf-8")
    DEST_INDEX_JSON.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(str(DEST_REFERENCES))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
