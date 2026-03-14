#!/usr/bin/env python3
from __future__ import annotations

import json
import sys
from pathlib import Path


def load_json(path: Path) -> dict:
    if not path.exists():
        return {}
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return {}
    return payload if isinstance(payload, dict) else {}


def main() -> int:
    if len(sys.argv) != 6:
        print(
            "usage: write-memory-hub-note.py <run_result.json> <run_summary.md> <run_dir> <out_md> <out_json>",
            file=sys.stderr,
        )
        return 2

    run_result_path = Path(sys.argv[1])
    run_summary_path = Path(sys.argv[2])
    run_dir = Path(sys.argv[3])
    out_md = Path(sys.argv[4])
    out_json = Path(sys.argv[5])

    run_result = load_json(run_result_path)
    design_result = load_json(run_dir / "design-result.json")
    host_qa_result = load_json(run_dir / "focus-host-qa-result.json")

    payload = {
        "run_id": run_result.get("run_id") or run_dir.name,
        "state": run_result.get("state", "unknown"),
        "task_id": run_result.get("task_id"),
        "task_title": run_result.get("task_title"),
        "focus_section": run_result.get("focus_section"),
        "focus_label": run_result.get("focus_label"),
        "host_qa_status": run_result.get("host_qa_status", "skipped"),
        "design_result_status": run_result.get("design_result_status", "skipped"),
        "auto_commit_sha": run_result.get("auto_commit_sha"),
        "run_dir": str(run_dir),
        "run_summary_path": str(run_summary_path),
        "run_result_path": str(run_result_path),
        "host_qa_result_path": str(run_dir / "focus-host-qa-result.json") if (run_dir / "focus-host-qa-result.json").exists() else None,
        "design_result_path": str(run_dir / "design-result.json") if (run_dir / "design-result.json").exists() else None,
        "figma_bundle_summary_path": run_result.get("figma_bundle_summary_path"),
        "host_qa_overall_status": host_qa_result.get("overall_status"),
        "design_overall_status": design_result.get("overall_status"),
    }

    md_lines = [
        "# Automation Run Memory Note",
        "",
        f"- run_id: `{payload['run_id']}`",
        f"- state: `{payload['state']}`",
        f"- task_id: `{payload.get('task_id') or 'none'}`",
        f"- task_title: `{payload.get('task_title') or 'none'}`",
        f"- focus_section: `{payload.get('focus_section') or 'none'}`",
        f"- focus_label: `{payload.get('focus_label') or 'none'}`",
        f"- host_qa_status: `{payload.get('host_qa_status') or 'skipped'}`",
        f"- design_result_status: `{payload.get('design_result_status') or 'skipped'}`",
        f"- auto_commit_sha: `{payload.get('auto_commit_sha') or 'none'}`",
        f"- run_dir: `{payload['run_dir']}`",
        f"- run_summary_path: `{payload['run_summary_path']}`",
        f"- run_result_path: `{payload['run_result_path']}`",
    ]

    if payload.get("host_qa_result_path"):
        md_lines.append(f"- host_qa_result_path: `{payload['host_qa_result_path']}`")
    if payload.get("design_result_path"):
        md_lines.append(f"- design_result_path: `{payload['design_result_path']}`")
    if payload.get("figma_bundle_summary_path"):
        md_lines.append(f"- figma_bundle_summary_path: `{payload['figma_bundle_summary_path']}`")

    if run_summary_path.exists():
        summary_text = run_summary_path.read_text(encoding="utf-8").strip()
        if summary_text:
            md_lines.extend(["", "## Batch Summary", "", summary_text])

    out_md.parent.mkdir(parents=True, exist_ok=True)
    out_json.parent.mkdir(parents=True, exist_ok=True)
    out_md.write_text("\n".join(md_lines) + "\n", encoding="utf-8")
    out_json.write_text(json.dumps(payload, ensure_ascii=True, indent=2) + "\n", encoding="utf-8")

    print(out_md)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
