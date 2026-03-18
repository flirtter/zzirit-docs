#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import subprocess
from pathlib import Path
from typing import Any


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Capture one screen and top child assets per tab using the live Figma CDP session.",
    )
    parser.add_argument(
        "--screens-manifest",
        default="/Users/user/zzirit-v2/artifacts/figma-reference/catalog/screens-manifest.json",
    )
    parser.add_argument(
        "--assets-manifest",
        default="/Users/user/zzirit-v2/artifacts/figma-reference/catalog/assets-manifest.json",
    )
    parser.add_argument(
        "--run-root",
        default="",
        help="Optional explicit run root. Defaults to artifacts/figma-reference/bundles/<timestamp>.",
    )
    parser.add_argument(
        "--assets-per-tab",
        type=int,
        default=2,
    )
    parser.add_argument(
        "--design-file",
        default="/Users/user/zzirit-v2/artifacts/figma-api/design-file.json",
    )
    parser.add_argument(
        "--state-file",
        default="/Users/user/zzirit-v2/artifacts/figma-reference/catalog/bundle-state.json",
    )
    parser.add_argument(
        "--skip-cached",
        dest="skip_cached",
        action="store_true",
        default=True,
    )
    parser.add_argument(
        "--no-skip-cached",
        dest="skip_cached",
        action="store_false",
    )
    parser.add_argument(
        "--tabs",
        nargs="*",
        default=[],
        help="Optional tab keys to limit the run, for example: lightning meeting",
    )
    return parser.parse_args()


def run_command(command: list[str], env: dict[str, str] | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(command, text=True, capture_output=True, env=env)


def choose_primary_screen(tab: dict[str, Any]) -> dict[str, Any] | None:
    for item in tab.get("screen_references", []):
        if item.get("node_id"):
            return item
    return None


def load_json(path: Path, default: Any) -> Any:
    if not path.exists():
        return default
    return json.loads(path.read_text(encoding="utf-8"))


def state_key(tab_key: str, item_kind: str, node_id: str) -> str:
    return f"{tab_key}:{item_kind}:{node_id}"


def build_design_signature(screens_manifest: dict[str, Any], design_file_path: Path) -> dict[str, str]:
    signature = {
        "file_key": screens_manifest.get("figma_file", {}).get("key", ""),
        "design_last_modified": "",
        "design_name": screens_manifest.get("figma_file", {}).get("name", ""),
        "design_version": "",
    }
    if design_file_path.exists():
        design_payload = load_json(design_file_path, {})
        signature["design_last_modified"] = design_payload.get("lastModified", "")
        signature["design_version"] = design_payload.get("version", "")
    return signature


def should_reuse_cached_entry(
    *,
    state: dict[str, Any],
    state_key_value: str,
    design_signature: dict[str, str],
) -> dict[str, Any] | None:
    entry = state.get("entries", {}).get(state_key_value)
    if not entry:
        return None
    if entry.get("design_signature") != design_signature:
        return None
    raw_path = entry.get("raw_path", "")
    cropped_path = entry.get("cropped_path", "")
    status = entry.get("status", "")
    if not raw_path or not Path(raw_path).exists():
        return None
    if status == "ok" and cropped_path and Path(cropped_path).exists():
        return entry
    if status == "raw_only":
        return entry
    return None


def write_state(path: Path, state: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(state, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def capture_node(
    *,
    project_root: Path,
    node_id: str,
    raw_path: Path,
    cropped_path: Path,
    mode: str,
) -> dict[str, Any]:
    env = os.environ.copy()
    env["FIGMA_NODE_ID"] = node_id
    env["FIGMA_OUTPUT_PATH"] = str(raw_path)

    screenshot = run_command(
        ["node", str(project_root / "scripts/review/figma-cdp-screenshot-node.cjs")],
        env=env,
    )

    result: dict[str, Any] = {
        "node_id": node_id,
        "status": "error",
        "raw_path": str(raw_path),
        "cropped_path": str(cropped_path),
        "meta_stdout": screenshot.stdout,
        "meta_stderr": screenshot.stderr,
        "capture_mode": mode,
    }

    if screenshot.returncode != 0:
        return result

    crop_args = [
        "python3",
        str(project_root / "scripts/review/detect-figma-selection-crop.py"),
        str(raw_path),
        str(cropped_path),
    ]
    if mode == "screen":
        crop_args += ["--padding", "8", "--min-width", "180", "--min-height", "180"]
    else:
        crop_args += ["--padding", "6", "--min-width", "30", "--min-height", "30"]

    crop = run_command(crop_args)
    result["crop_stdout"] = crop.stdout
    result["crop_stderr"] = crop.stderr
    if crop.returncode == 0 and cropped_path.exists():
        result["status"] = "ok"
    elif raw_path.exists():
        result["status"] = "raw_only"
    return result


def capture_item(
    *,
    project_root: Path,
    target_dir: Path,
    file_stem: str,
    node_id: str,
    mode: str,
) -> dict[str, Any]:
    raw_path = target_dir / f"{file_stem}-raw.png"
    cropped_path = target_dir / f"{file_stem}-cropped.png"
    meta_path = target_dir / f"{file_stem}.json"
    err_path = target_dir / f"{file_stem}.err"
    target_dir.mkdir(parents=True, exist_ok=True)

    result = capture_node(
        project_root=project_root,
        node_id=node_id,
        raw_path=raw_path,
        cropped_path=cropped_path,
        mode=mode,
    )
    meta_path.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
    err_path.write_text(
        "".join(
            [
                result.get("meta_stderr", ""),
                result.get("crop_stderr", ""),
            ]
        )
    )
    return result


def sanitize_name(value: str) -> str:
    safe = []
    for ch in value.lower():
        if ch.isalnum():
            safe.append(ch)
        elif ch in {"-", "_"}:
            safe.append(ch)
        else:
            safe.append("-")
    out = "".join(safe).strip("-")
    while "--" in out:
        out = out.replace("--", "-")
    return out or "item"


def summarize_result(item_kind: str, result: dict[str, Any], title: str, node_id: str, category: str = "") -> list[str]:
    label = f"- [{item_kind}:{result['status']}] `{node_id}` `{title}`"
    if category:
        label += f" `{category}`"
    lines = [label, f"  - raw: `{result['raw_path']}`"]
    cropped_path = result.get("cropped_path", "")
    if cropped_path and Path(cropped_path).exists():
        lines.append(f"  - cropped: `{cropped_path}`")
    if result["status"] == "skipped_existing":
        lines.append("  - note: reused cached Figma node capture")
    return lines


def main() -> int:
    args = parse_args()
    project_root = Path(__file__).resolve().parents[2]
    screens_manifest_path = Path(args.screens_manifest)
    assets_manifest_path = Path(args.assets_manifest)
    design_file_path = Path(args.design_file)
    state_file_path = Path(args.state_file)

    with open(screens_manifest_path) as f:
        screens_manifest = json.load(f)
    with open(assets_manifest_path) as f:
        assets_manifest = json.load(f)

    tabs_filter = set(args.tabs)
    design_signature = build_design_signature(screens_manifest, design_file_path)
    state = load_json(state_file_path, {"version": 1, "entries": {}})
    run_root = (
        Path(args.run_root)
        if args.run_root
        else project_root / "artifacts/figma-reference/bundles" / subprocess.check_output(["date", "+%Y%m%d-%H%M%S"], text=True).strip()
    )
    run_root.mkdir(parents=True, exist_ok=True)

    assets_by_alias = {section["alias"]: section for section in assets_manifest.get("sections", [])}
    summary_lines = [
        "# Figma CDP Bundle Capture",
        "",
        f"- run_root: {run_root}",
        f"- assets_per_tab: {args.assets_per_tab}",
        f"- state_file: {state_file_path}",
        f"- skip_cached: {'yes' if args.skip_cached else 'no'}",
        f"- design_last_modified: {design_signature.get('design_last_modified') or 'unknown'}",
        "",
        "## Results",
    ]

    for tab in screens_manifest.get("tabs", []):
        tab_key = tab.get("tab_key", "")
        if tabs_filter and tab_key not in tabs_filter:
            continue
        tab_dir = run_root / tab_key
        screen_dir = tab_dir / "screen"
        assets_dir = tab_dir / "assets"
        section_assets = assets_by_alias.get(tab_key, {})

        summary_lines.append(f"### {tab_key}")
        primary = choose_primary_screen(tab)
        if primary is None:
            summary_lines.append("- [skip] no screen node_id")
            summary_lines.append("")
            continue

        screen_name = sanitize_name(primary.get("screen_key") or f"{tab_key}-screen")
        screen_state_key = state_key(tab_key, "screen", primary["node_id"])
        cached_screen = should_reuse_cached_entry(
            state=state,
            state_key_value=screen_state_key,
            design_signature=design_signature,
        ) if args.skip_cached else None

        if cached_screen is not None:
            screen_result = {
                **cached_screen,
                "status": "skipped_existing",
            }
        else:
            screen_result = capture_item(
                project_root=project_root,
                target_dir=screen_dir,
                file_stem=screen_name,
                node_id=primary["node_id"],
                mode="screen",
            )
            state.setdefault("entries", {})[screen_state_key] = {
                "tab_key": tab_key,
                "item_kind": "screen",
                "screen_key": primary.get("screen_key", ""),
                "node_id": primary["node_id"],
                "status": screen_result["status"],
                "raw_path": screen_result["raw_path"],
                "cropped_path": screen_result["cropped_path"],
                "design_signature": design_signature,
            }
            write_state(state_file_path, state)

        summary_lines.extend(
            summarize_result(
                "screen",
                screen_result,
                primary.get("screen_key") or tab_key,
                primary["node_id"],
            )
        )
        if screen_result["status"] in {"raw_only", "skipped_existing"} and not Path(screen_result.get("cropped_path", "")).exists():
            summary_lines.append("  - drift_signal: high")
            summary_lines.append("  - reason: screen reference is only available as raw canvas capture; compare structure against child assets and existing manual references")

        candidates = section_assets.get("candidates", [])[: args.assets_per_tab]
        if not candidates:
            summary_lines.append("- [assets:skip] no asset candidates")
            summary_lines.append("")
            continue

        for idx, candidate in enumerate(candidates, start=1):
            rep = candidate["representative"]
            asset_name = sanitize_name(rep.get("name") or f"asset-{idx}")
            file_stem = f"{idx:02d}-{asset_name}"
            asset_state_key = state_key(tab_key, "asset", rep["node_id"])
            cached_asset = should_reuse_cached_entry(
                state=state,
                state_key_value=asset_state_key,
                design_signature=design_signature,
            ) if args.skip_cached else None

            if cached_asset is not None:
                asset_result = {
                    **cached_asset,
                    "status": "skipped_existing",
                }
            else:
                asset_result = capture_item(
                    project_root=project_root,
                    target_dir=assets_dir,
                    file_stem=file_stem,
                    node_id=rep["node_id"],
                    mode="asset",
                )
                state.setdefault("entries", {})[asset_state_key] = {
                    "tab_key": tab_key,
                    "item_kind": "asset",
                    "node_id": rep["node_id"],
                    "name": rep.get("name", ""),
                    "category": rep.get("category", ""),
                    "status": asset_result["status"],
                    "raw_path": asset_result["raw_path"],
                    "cropped_path": asset_result["cropped_path"],
                    "design_signature": design_signature,
                }
                write_state(state_file_path, state)

            summary_lines.extend(
                summarize_result(
                    "asset",
                    asset_result,
                    rep.get("name") or "<unnamed>",
                    rep["node_id"],
                    rep.get("category") or "",
                )
            )
        summary_lines.append("")

    (run_root / "summary.md").write_text("\n".join(summary_lines) + "\n")
    print(run_root)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
