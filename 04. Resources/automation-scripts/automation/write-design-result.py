#!/usr/bin/env python3
from __future__ import annotations

import json
import sys
from pathlib import Path


UI_SECTIONS = {"login", "onboarding", "lightning", "meeting", "chat", "likes", "my"}
MANUAL_SECTION_ALIASES = {"my": "MY", "likes": "MY"}
PASS_HOST_QA = {"pass", "completed", "success"}
SURFACE_SPEC_MANIFEST = Path("/Users/user/zzirit-v2/docs/spec/surfaces/manifest.json")


def load_json(path: Path) -> dict:
    if not path.exists():
        return {}
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return {}
    return payload if isinstance(payload, dict) else {}


def load_surface_spec(section: str) -> dict[str, object]:
    payload = load_json(SURFACE_SPEC_MANIFEST)
    surfaces = payload.get("surfaces") if isinstance(payload.get("surfaces"), list) else []
    for item in surfaces:
        if isinstance(item, dict) and str(item.get("id", "")).strip() == section:
            return item
    return {}


def parse_summary_status(path: Path) -> str:
    if not path.exists():
        return "missing"
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if line.startswith("- status:"):
            return line.split(":", 1)[1].strip() or "missing"
    return "unknown"


def normalize_section_name(section: str) -> str:
    return MANUAL_SECTION_ALIASES.get(section, section)


def collect_manual_reference_info(manual_ref_root: Path, section: str) -> dict[str, object]:
    catalog_path = manual_ref_root / "catalog.md"
    section_name = normalize_section_name(section)
    section_dir = manual_ref_root / section_name if section_name else manual_ref_root / "__missing__"
    image_paths = sorted(
        path
        for path in section_dir.rglob("*")
        if path.is_file() and path.suffix.lower() in {".png", ".jpg", ".jpeg", ".webp", ".pdf"}
    ) if section_dir.exists() else []
    return {
        "catalog_path": str(catalog_path),
        "catalog_exists": catalog_path.exists(),
        "section_dir": str(section_dir),
        "section_exists": section_dir.exists(),
        "image_count": len(image_paths),
        "sample_images": [str(path) for path in image_paths[:8]],
    }


def collect_host_qa_info(host_qa_result_path: Path, host_qa_summary_path: Path, run_dir: Path) -> dict[str, object]:
    payload = load_json(host_qa_result_path)
    host_status = str(payload.get("overall_status", "missing")) if payload else "missing"
    artifacts = payload.get("artifacts", {}) if isinstance(payload.get("artifacts"), dict) else {}
    existing_artifacts: dict[str, str] = {}
    for key, raw_value in artifacts.items():
        value = str(raw_value).strip()
        if not value:
            continue
        candidate = Path(value)
        if not candidate.is_absolute():
            candidate = (run_dir / candidate).resolve()
        if candidate.exists():
            existing_artifacts[str(key)] = str(candidate)
    release_clean_artifacts = {
        key: value
        for key, value in existing_artifacts.items()
        if "/artifacts/manual-review/" in value
    }
    return {
        "result_path": str(host_qa_result_path),
        "result_exists": host_qa_result_path.exists(),
        "summary_path": str(host_qa_summary_path),
        "summary_exists": host_qa_summary_path.exists(),
        "overall_status": host_status,
        "artifact_count": len(existing_artifacts),
        "artifacts": existing_artifacts,
        "release_clean_artifact_count": len(release_clean_artifacts),
        "release_clean_artifacts": release_clean_artifacts,
        "capture_quality": "release_clean" if release_clean_artifacts else ("artifact_only" if existing_artifacts else "missing"),
        "steps": payload.get("steps", []) if isinstance(payload.get("steps"), list) else [],
    }


def collect_figma_bundle_info(summary_path: Path) -> dict[str, object]:
    return {
        "summary_path": str(summary_path),
        "summary_exists": summary_path.exists(),
        "status": parse_summary_status(summary_path),
    }


def requires_release_clean_capture(surface_spec: dict[str, object]) -> bool:
    next_step = str(surface_spec.get("next_step", "")).lower()
    blockers = [str(item).lower() for item in surface_spec.get("blockers", []) if item]
    return "release" in next_step or any("release clean capture" in item for item in blockers)


def derive_overall_status(
    section: str,
    surface_spec: dict[str, object],
    manual_info: dict[str, object],
    host_qa_info: dict[str, object],
    figma_info: dict[str, object],
) -> tuple[str, list[str]]:
    notes: list[str] = []
    if section not in UI_SECTIONS:
        notes.append("non-ui section; design gating skipped")
        return "skipped", notes

    references_present = bool(manual_info.get("section_exists")) or bool(figma_info.get("summary_exists"))
    if not references_present:
        notes.append("missing manual section references and figma bundle summary")
        return "blocked", notes

    host_status = str(host_qa_info.get("overall_status", "missing"))
    if host_status == "blocked":
        notes.append("host QA reported blocked")
        return "blocked", notes

    if host_status in PASS_HOST_QA:
        if int(host_qa_info.get("artifact_count", 0) or 0) > 0 or bool(host_qa_info.get("summary_exists")):
            if requires_release_clean_capture(surface_spec) and int(host_qa_info.get("release_clean_artifact_count", 0) or 0) == 0:
                notes.append("host QA passed but release clean capture is still missing for this surface")
                return "partial", notes
            notes.append("host QA passed with capture evidence and design references")
            return "pass", notes
        notes.append("host QA passed but no artifact evidence was recorded")
        return "partial", notes

    if host_status == "skipped":
        notes.append("host QA skipped; design references prepared but capture was not verified")
        return "partial", notes

    notes.append("design references prepared but host QA result was not pass")
    return "partial", notes


def main() -> int:
    if len(sys.argv) != 8:
        raise SystemExit(
            "usage: write-design-result.py <focus_section> <run_dir> <host_qa_result.json> <host_qa_summary.md> <figma_bundle_summary.md> <manual_ref_root> <output_path>"
        )

    focus_section = sys.argv[1].strip()
    run_dir = Path(sys.argv[2]).resolve()
    host_qa_result_path = Path(sys.argv[3]) if sys.argv[3] else Path()
    host_qa_summary_path = Path(sys.argv[4]) if sys.argv[4] else Path()
    figma_bundle_summary_path = Path(sys.argv[5]) if sys.argv[5] else Path()
    manual_ref_root = Path(sys.argv[6]).resolve()
    output_path = Path(sys.argv[7]).resolve()

    surface_spec = load_surface_spec(focus_section)
    manual_info = collect_manual_reference_info(manual_ref_root, focus_section)
    host_qa_info = collect_host_qa_info(host_qa_result_path, host_qa_summary_path, run_dir)
    figma_info = collect_figma_bundle_info(figma_bundle_summary_path)
    overall_status, notes = derive_overall_status(focus_section, surface_spec, manual_info, host_qa_info, figma_info)

    payload = {
        "focus_section": focus_section or None,
        "run_dir": str(run_dir),
        "overall_status": overall_status,
        "surface_spec": surface_spec,
        "manual_design": manual_info,
        "host_qa": host_qa_info,
        "figma_bundle": figma_info,
        "notes": notes,
    }
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(payload, ensure_ascii=True, indent=2) + "\n", encoding="utf-8")
    print(str(output_path))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
