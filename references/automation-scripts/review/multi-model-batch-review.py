#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
from datetime import datetime
from pathlib import Path


def run(
    command: list[str],
    *,
    cwd: Path,
    input_text: str | None = None,
    check: bool = True,
    timeout_seconds: int | None = None,
) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        command,
        cwd=str(cwd),
        input=input_text,
        text=True,
        capture_output=True,
        check=check,
        timeout=timeout_seconds,
    )


def git_output(root: Path, *args: str) -> str:
    return run(["git", *args], cwd=root).stdout


def shell_quote(path: Path) -> str:
    return str(path)


def truncate_lines(text: str, max_lines: int) -> str:
    if max_lines <= 0:
        return ""
    return "\n".join(text.splitlines()[:max_lines]).strip()


def read_text_if_exists(path: Path) -> str:
    if not path.exists():
        return ""
    return path.read_text(encoding="utf-8")


def ensure_text(value: str | bytes | None) -> str:
    if value is None:
        return ""
    if isinstance(value, bytes):
        return value.decode("utf-8", errors="replace")
    return value


def truncate_items(items: list[str], max_items: int) -> list[str]:
    if len(items) <= max_items:
        return items
    kept = items[:max_items]
    kept.append(f"- ... {len(items) - max_items} more")
    return kept


def build_shared_sections(
    *,
    root: Path,
    summary_text: str,
    changed_files: list[str],
    diffstat_text: str,
    gap_audit_text: str,
    design_baseline_text: str,
) -> tuple[bool, list[str], list[str]]:
    ui_touched = any(
        path.startswith(
            (
                "apps/mobile/app/",
                "apps/mobile/components/",
                "apps/mobile/constants/",
                "apps/mobile/features/",
            )
        )
        or "/theme" in path
        for path in changed_files
    )
    changed_file_lines = [f"- {path}" for path in changed_files] if changed_files else ["- none"]
    changed_file_lines = truncate_items(changed_file_lines, 20)
    shared_sections = [
        f"- repo_root: {shell_quote(root)}",
        f"- ui_touched: {'yes' if ui_touched else 'no'}",
        "",
        "## Latest Batch Summary",
        "",
        summary_text.strip() or "No latest summary available.",
        "",
        "## Changed Files",
        "",
        *changed_file_lines,
        "",
        "## Diff Stat",
        "",
        diffstat_text.strip() or "No diffstat available.",
    ]
    ui_sections: list[str] = []
    if ui_touched:
        ui_sections = [
            "",
            "## Gap Audit Excerpt",
            "",
            gap_audit_text.strip() or "No gap audit available.",
            "",
            "## Design Baseline Excerpt",
            "",
            design_baseline_text.strip() or "No design baseline available.",
        ]
    return ui_touched, shared_sections, ui_sections


def build_gemini_prompt(
    *,
    root: Path,
    summary_text: str,
    changed_files: list[str],
    diffstat_text: str,
    diff_text: str,
    gap_audit_text: str,
    design_baseline_text: str,
) -> str:
    ui_touched, shared_sections, ui_sections = build_shared_sections(
        root=root,
        summary_text=summary_text,
        changed_files=changed_files,
        diffstat_text=diffstat_text,
        gap_audit_text=gap_audit_text,
        design_baseline_text=design_baseline_text,
    )
    lines = [
        "# Gemini Batch Review",
        "",
        "You are writing post-run advisory QA notes for one development batch.",
        "Focus on high-confidence bugs, regressions, missing tests, broken flows, and UI drift in touched screens.",
        "This review is advisory only. The main automation lane already completed implementation and host QA; do not behave like a release gate.",
        "For lightning, meeting, chat, and my screens, treat the legacy `/Users/user/zzirit-rn` implementation as the baseline unless the new result is clearly better; call out unjustified drift away from legacy flow or composition.",
        "If duplicate routes or overlapping owners appear in the diff, treat blind deletion as risky when the removed file may contain unique product spec; prefer findings that require merging unique behavior into the surviving owner before cleanup.",
        "Keep it short and concrete. No praise.",
        "",
        "Output format:",
        "1. Findings",
        "2. Risks",
        "3. Suggested next patch",
        "",
        *shared_sections,
        *ui_sections,
        "",
        "## Diff Excerpt",
        "",
        "```diff",
        diff_text.rstrip() or "(no diff excerpt)",
        "```",
        "",
        "If there are no material findings, say 'no critical findings'.",
    ]
    return "\n".join(lines) + "\n"


def build_claude_prompt(
    *,
    root: Path,
    summary_text: str,
    changed_files: list[str],
    diffstat_text: str,
    diff_text: str,
    gap_audit_text: str,
    design_baseline_text: str,
) -> str:
    ui_touched, shared_sections, ui_sections = build_shared_sections(
        root=root,
        summary_text=summary_text,
        changed_files=changed_files,
        diffstat_text=diffstat_text,
        gap_audit_text=gap_audit_text,
        design_baseline_text=design_baseline_text,
    )
    lines = [
        "# Claude Batch Review",
        "",
        "Review this development batch as an advisory planning and delivery reviewer.",
        "Prioritize omissions, wrong sequencing, product drift, and whether the next batch focus is correct.",
        "This review is advisory only and should not act as a release gate.",
        "For lightning, meeting, chat, and my screens, use the legacy `/Users/user/zzirit-rn` implementation as the default baseline and call out when the batch diverges without a clear reason that makes the new result better.",
        "If duplicate routes or overlapping owners appear, call out when the duplicate contains unique product spec that should be migrated before cleanup.",
        "Do not rewrite the entire project. Keep the answer concise and actionable.",
        "",
        "Output format:",
        "1. Findings",
        "2. Risks",
        "3. Recommended next batch",
        "",
        *shared_sections,
        *ui_sections,
        "",
        "## Small Diff Excerpt",
        "",
        "```diff",
        diff_text.rstrip() or "(no diff excerpt)",
        "```",
        "",
        f"UI parity matters: {'yes' if ui_touched else 'no'}.",
        "Call out if this batch is still spending time on the wrong priority.",
    ]
    return "\n".join(lines) + "\n"


def run_model(
    *,
    model_name: str,
    command: list[str],
    root: Path,
    run_dir: Path,
    timeout_seconds: int,
    input_text: str | None = None,
) -> dict[str, str]:
    stdout_path = run_dir / f"{model_name}-review.md"
    stderr_path = run_dir / f"{model_name}.log"

    if shutil.which(command[0]) is None:
        message = f"{model_name} CLI not found: {command[0]}"
        stdout_path.write_text(message + "\n", encoding="utf-8")
        stderr_path.write_text(message + "\n", encoding="utf-8")
        return {
            "model": model_name,
            "status": "missing",
            "stdout_path": str(stdout_path),
            "stderr_path": str(stderr_path),
        }

    try:
        completed = run(
            command,
            cwd=root,
            input_text=input_text,
            check=False,
            timeout_seconds=timeout_seconds,
        )
    except subprocess.TimeoutExpired as exc:
        stdout_path.write_text(ensure_text(exc.stdout).strip() + "\n", encoding="utf-8")
        stderr_path.write_text(
            f"TimeoutExpired: {exc}\n{ensure_text(exc.stderr).strip()}\n",
            encoding="utf-8",
        )
        return {
            "model": model_name,
            "status": "timeout",
            "stdout_path": str(stdout_path),
            "stderr_path": str(stderr_path),
        }
    except Exception as exc:  # pragma: no cover - defensive
        stdout_path.write_text("", encoding="utf-8")
        stderr_path.write_text(f"{type(exc).__name__}: {exc}\n", encoding="utf-8")
        return {
            "model": model_name,
            "status": "error",
            "stdout_path": str(stdout_path),
            "stderr_path": str(stderr_path),
        }

    stdout_path.write_text(completed.stdout.strip() + "\n", encoding="utf-8")
    stderr_path.write_text(completed.stderr.strip() + "\n", encoding="utf-8")

    return {
        "model": model_name,
        "status": "ok" if completed.returncode == 0 else "error",
        "stdout_path": str(stdout_path),
        "stderr_path": str(stderr_path),
        "exit_code": str(completed.returncode),
    }


def main() -> int:
    root = Path(os.environ.get("ZZIRIT_REVIEW_ROOT", Path(__file__).resolve().parents[2]))
    artifact_root = Path(
        os.environ.get("ZZIRIT_REVIEW_ARTIFACT_ROOT", root / "artifacts" / "model-review")
    )
    run_id = os.environ.get("ZZIRIT_REVIEW_RUN_ID", datetime.now().strftime("%Y%m%d-%H%M%S-%f"))
    run_dir = artifact_root / run_id
    run_dir.mkdir(parents=True, exist_ok=True)

    latest_summary_path = Path(
        os.environ.get(
            "ZZIRIT_REVIEW_BATCH_SUMMARY",
            root / "artifacts" / "automation" / "latest-summary.md",
        )
    )
    results_path = run_dir / "results.json"
    prompt_path = run_dir / "prompt.md"
    gemini_prompt_path = run_dir / "gemini-prompt.md"
    claude_prompt_path = run_dir / "claude-prompt.md"
    summary_path = run_dir / "summary.md"
    diffstat_path = run_dir / "diffstat.txt"
    diff_path = run_dir / "diff.diff"
    changed_files_path = run_dir / "changed-files.txt"

    max_diff_lines = int(os.environ.get("ZZIRIT_REVIEW_MAX_DIFF_LINES", "120"))
    gemini_max_diff_lines = int(os.environ.get("ZZIRIT_REVIEW_MAX_DIFF_LINES_GEMINI", str(max_diff_lines)))
    claude_max_diff_lines = int(os.environ.get("ZZIRIT_REVIEW_MAX_DIFF_LINES_CLAUDE", "30"))
    max_summary_lines = int(os.environ.get("ZZIRIT_REVIEW_MAX_SUMMARY_LINES", "36"))
    max_gap_lines = int(os.environ.get("ZZIRIT_REVIEW_MAX_GAP_LINES", "24"))
    max_design_lines = int(os.environ.get("ZZIRIT_REVIEW_MAX_DESIGN_LINES", "32"))
    max_diffstat_lines = int(os.environ.get("ZZIRIT_REVIEW_MAX_DIFFSTAT_LINES", "24"))
    timeout_seconds = int(os.environ.get("ZZIRIT_REVIEW_TIMEOUT_SECONDS", "90"))
    gemini_model = os.environ.get("ZZIRIT_REVIEW_GEMINI_MODEL", "gemini-2.5-flash")
    claude_model = os.environ.get("ZZIRIT_REVIEW_CLAUDE_MODEL", "haiku")
    models = [
        item.strip()
        for item in os.environ.get("ZZIRIT_REVIEW_MODELS", "gemini").split(",")
        if item.strip()
    ]

    changed_files = [
        line
        for line in git_output(root, "diff", "--name-only").splitlines()
        if line.strip()
    ]
    if not changed_files:
        changed_files = [
            line[3:] if len(line) > 3 else line
            for line in git_output(root, "status", "--short").splitlines()
            if line.strip()
        ]

    diffstat_text = truncate_lines(git_output(root, "diff", "--stat"), max_diffstat_lines)
    diff_text = git_output(
        root,
        "diff",
        "--unified=1",
        "--",
        ".",
        ":(exclude)package-lock.json",
        ":(exclude)apps/mobile/package-lock.json",
    )
    full_gap_audit_text = read_text_if_exists(root / "docs/spec/gap-audit-20260308.md")
    full_design_baseline_text = read_text_if_exists(root / "docs/spec/design-baseline.md")
    full_summary_text = (
        latest_summary_path.read_text(encoding="utf-8")
        if latest_summary_path.exists()
        else "No latest automation summary."
    )
    summary_text = truncate_lines(full_summary_text, max_summary_lines)
    gap_audit_text = truncate_lines(full_gap_audit_text, max_gap_lines)
    design_baseline_text = truncate_lines(full_design_baseline_text, max_design_lines)
    gemini_diff_text = truncate_lines(diff_text, gemini_max_diff_lines) or "(no diff excerpt)"
    claude_diff_text = truncate_lines(diff_text, claude_max_diff_lines) or "(no diff excerpt)"

    changed_files_path.write_text("\n".join(changed_files) + "\n", encoding="utf-8")
    diffstat_path.write_text(diffstat_text, encoding="utf-8")
    diff_path.write_text(gemini_diff_text + "\n", encoding="utf-8")

    gemini_prompt = build_gemini_prompt(
        root=root,
        summary_text=summary_text,
        changed_files=changed_files,
        diffstat_text=diffstat_text,
        diff_text=gemini_diff_text,
        gap_audit_text=gap_audit_text,
        design_baseline_text=design_baseline_text,
    )
    claude_prompt = build_claude_prompt(
        root=root,
        summary_text=summary_text,
        changed_files=changed_files,
        diffstat_text=diffstat_text,
        diff_text=claude_diff_text,
        gap_audit_text=gap_audit_text,
        design_baseline_text=design_baseline_text,
    )
    prompt_path.write_text(gemini_prompt, encoding="utf-8")
    gemini_prompt_path.write_text(gemini_prompt, encoding="utf-8")
    claude_prompt_path.write_text(claude_prompt, encoding="utf-8")

    review_results: list[dict[str, str]] = []

    for model in models:
        if model == "gemini":
            review_results.append(
                run_model(
                    model_name="gemini",
                    command=[
                        "gemini",
                        "-m",
                        gemini_model,
                        "--output-format",
                        "text",
                        "--prompt",
                        gemini_prompt,
                    ],
                    root=root,
                    run_dir=run_dir,
                    timeout_seconds=timeout_seconds,
                )
            )
        elif model == "claude":
            review_results.append(
                run_model(
                    model_name="claude",
                    command=[
                        "claude",
                        "-p",
                        "--output-format",
                        "text",
                        "--no-session-persistence",
                        "--model",
                        claude_model,
                        "--effort",
                        "low",
                        "--tools",
                        "",
                        "--permission-mode",
                        "bypassPermissions",
                        claude_prompt,
                    ],
                    root=root,
                    run_dir=run_dir,
                    timeout_seconds=timeout_seconds,
                )
            )

    results_path.write_text(json.dumps(review_results, ensure_ascii=True, indent=2) + "\n", encoding="utf-8")

    summary_lines = [
        "# Advisory Model Review Summary",
        "",
        f"- run_id: {run_id}",
        "- mode: advisory-md-only",
        "- note: this artifact is for later QA/implementation follow-up and should not block the main automation batch",
        f"- prompt: {prompt_path}",
        f"- gemini_prompt: {gemini_prompt_path}",
        f"- claude_prompt: {claude_prompt_path}",
        f"- changed_files: {changed_files_path}",
        f"- diffstat: {diffstat_path}",
        "",
        "## Models",
        "",
    ]

    for item in review_results:
        summary_lines.extend(
            [
                f"- {item['model']}: {item['status']}",
                f"  - review: {item['stdout_path']}",
                f"  - log: {item['stderr_path']}",
            ]
        )

    summary_lines.append("")
    summary_path.write_text("\n".join(summary_lines) + "\n", encoding="utf-8")
    print(summary_path)
    return 0


if __name__ == "__main__":
    sys.exit(main())
