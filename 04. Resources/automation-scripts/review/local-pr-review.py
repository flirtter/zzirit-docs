#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
from datetime import datetime
from pathlib import Path


TEXT_SUFFIXES_TO_SKIP = {
    ".7z",
    ".avi",
    ".bin",
    ".class",
    ".dll",
    ".eot",
    ".exe",
    ".gif",
    ".gz",
    ".icns",
    ".ico",
    ".jar",
    ".jpeg",
    ".jpg",
    ".lock",
    ".mov",
    ".mp3",
    ".mp4",
    ".otf",
    ".pdf",
    ".png",
    ".ttf",
    ".wav",
    ".webm",
    ".webp",
    ".woff",
    ".woff2",
    ".zip",
}


def run(
    command: list[str],
    *,
    cwd: Path,
    input_text: str | None = None,
    timeout_seconds: int | None = None,
    check: bool = True,
) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        command,
        cwd=str(cwd),
        input=input_text,
        text=True,
        capture_output=True,
        timeout=timeout_seconds,
        check=check,
    )


def ensure_text(value: str | bytes | None) -> str:
    if value is None:
        return ""
    if isinstance(value, bytes):
        return value.decode("utf-8", errors="replace")
    return value


def write_text(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


def truncate_lines(text: str, max_lines: int) -> str:
    if max_lines <= 0:
        return ""
    return "\n".join(text.splitlines()[:max_lines]).strip()


def truncate_items(items: list[str], max_items: int) -> list[str]:
    if len(items) <= max_items:
        return items
    kept = items[:max_items]
    kept.append(f"- ... {len(items) - max_items} more")
    return kept


def git_output(root: Path, *args: str) -> str:
    return run(["git", *args], cwd=root).stdout


def gh_json(root: Path, *args: str) -> object:
    completed = run(["gh", *args], cwd=root)
    return json.loads(completed.stdout)


def parse_repo_from_origin(root: Path) -> str:
    remote = git_output(root, "remote", "get-url", "origin").strip()
    match = re.search(r"github\.com[:/](?P<repo>[^/]+/[^/.]+)(?:\.git)?$", remote)
    if not match:
        raise SystemExit(f"Could not infer GitHub repo from origin remote: {remote}")
    return match.group("repo")


def is_text_candidate(path: str) -> bool:
    return Path(path).suffix.lower() not in TEXT_SUFFIXES_TO_SKIP


def score_file(entry: dict[str, object]) -> tuple[int, int, str]:
    path = str(entry.get("path", ""))
    additions = int(entry.get("additions") or 0)
    deletions = int(entry.get("deletions") or 0)
    churn = additions + deletions
    score = min(churn, 300)

    if not is_text_candidate(path):
        return (-1, churn, path)

    if re.search(r"(^|/)(tests?|__tests__|test_)", path):
        score += 240
    if re.search(r"(auth|login|token|firebase|deps|config|upload|seed|permission)", path):
        score += 260
    if re.search(r"(workflow|automation|parallel|gate|scheduler)", path):
        score += 220
    if re.search(r"(router|service|repository|schema|model|provider|api)", path):
        score += 120
    if re.search(r"(package\.json|pyproject\.toml|requirements\.txt|Dockerfile|README\.md)$", path):
        score += 140
    if path.endswith(".md"):
        score -= 40

    return (score, churn, path)


def select_focus_files(
    files: list[dict[str, object]],
    *,
    max_files: int,
) -> list[str]:
    ranked = sorted((score_file(entry) for entry in files), reverse=True)
    selected: list[str] = []
    for score, _churn, path in ranked:
        if score < 0 or not path:
            continue
        selected.append(path)
        if len(selected) >= max_files:
            break
    return selected


def build_focused_diff(
    *,
    root: Path,
    diff_range: str,
    focus_files: list[str],
    max_file_lines: int,
    max_total_lines: int,
) -> str:
    if not focus_files:
        return ""

    parts: list[str] = []
    total_lines = 0

    for path in focus_files:
        patch = git_output(root, "diff", "--unified=1", diff_range, "--", path)
        if not patch.strip():
            continue
        lines = patch.splitlines()
        if len(lines) > max_file_lines:
            lines = lines[:max_file_lines]
            lines.append(f"... truncated {len(patch.splitlines()) - max_file_lines} more lines for {path}")

        remaining = max_total_lines - total_lines
        if remaining <= 0:
            break
        if len(lines) > remaining:
            parts.extend(lines[:remaining])
            parts.append("... overall focused diff budget reached")
            break

        parts.extend(lines)
        total_lines += len(lines)

    return "\n".join(parts).strip()


def build_prompt(
    *,
    reviewer: str,
    pr: dict[str, object],
    changed_files: list[str],
    diffstat_text: str,
    focused_diff_text: str,
) -> str:
    changed_file_lines = truncate_items([f"- {path}" for path in changed_files], 40)
    review_goal = (
        "Focus on material bugs, regressions, security/auth issues, API/mobile contract drift, "
        "and missing tests or QA coverage introduced by this PR."
    )
    if reviewer == "claude":
        review_goal = (
            "Focus on material bugs, regressions, risky omissions, security/auth exposure, "
            "and whether the PR is missing tests or QA follow-through."
        )

    lines = [
        f"# {reviewer.capitalize()} Local PR Review",
        "",
        "You are reviewing a GitHub pull request for the ZZIRIT V2 repository.",
        review_goal,
        "Ignore style nits and praise. Findings first.",
        "",
        "Output format:",
        "1. Findings",
        "2. Risks",
        "3. Follow-up tests",
        "",
        f"- pr_number: {pr['number']}",
        f"- title: {pr['title']}",
        f"- url: {pr['url']}",
        f"- base: {pr['baseRefName']}",
        f"- head: {pr['headRefName']}",
        f"- changed_files_count: {len(changed_files)}",
        "",
        "## Changed Files",
        "",
        *changed_file_lines,
        "",
        "## Diff Stat",
        "",
        diffstat_text.strip() or "No diffstat available.",
        "",
        "## Focused Diff Excerpt",
        "",
        "```diff",
        focused_diff_text.strip() or "(no focused diff available)",
        "```",
        "",
        "If there are no material issues, say 'no critical findings'.",
    ]
    return "\n".join(lines) + "\n"


def run_codex(
    *,
    root: Path,
    run_dir: Path,
    prompt: str,
    timeout_seconds: int,
) -> dict[str, str]:
    output_path = run_dir / "codex-review.md"
    log_path = run_dir / "codex.log"
    stdout_path = run_dir / "codex.stdout.log"

    if shutil.which("codex") is None:
        message = "codex CLI not found"
        write_text(output_path, message + "\n")
        write_text(log_path, message + "\n")
        write_text(stdout_path, "")
        return {"model": "codex", "status": "missing", "output_path": str(output_path), "log_path": str(log_path)}

    try:
        completed = run(
            [
                "codex",
                "exec",
                "--ephemeral",
                "-C",
                str(root),
                "-o",
                str(output_path),
                prompt,
            ],
            cwd=root,
            timeout_seconds=timeout_seconds,
            check=False,
        )
    except subprocess.TimeoutExpired as exc:
        write_text(output_path, ensure_text(exc.stdout).strip() + "\n")
        write_text(log_path, f"TimeoutExpired: {exc}\n{ensure_text(exc.stderr)}\n")
        write_text(stdout_path, ensure_text(exc.stdout))
        return {"model": "codex", "status": "timeout", "output_path": str(output_path), "log_path": str(log_path)}

    write_text(stdout_path, completed.stdout)
    write_text(log_path, completed.stderr)
    if not output_path.exists():
        write_text(output_path, completed.stdout.strip() + "\n")

    return {
        "model": "codex",
        "status": "ok" if completed.returncode == 0 else "error",
        "output_path": str(output_path),
        "log_path": str(log_path),
        "stdout_path": str(stdout_path),
        "exit_code": str(completed.returncode),
    }


def run_claude(
    *,
    root: Path,
    run_dir: Path,
    prompt: str,
    timeout_seconds: int,
) -> dict[str, str]:
    output_path = run_dir / "claude-review.md"
    log_path = run_dir / "claude.log"

    if shutil.which("claude") is None:
        message = "claude CLI not found"
        write_text(output_path, message + "\n")
        write_text(log_path, message + "\n")
        return {"model": "claude", "status": "missing", "output_path": str(output_path), "log_path": str(log_path)}

    try:
        completed = run(
            [
                "claude",
                "-p",
                "--output-format",
                "text",
                "--no-session-persistence",
                "--model",
                os.environ.get("ZZIRIT_PR_REVIEW_CLAUDE_MODEL", "sonnet"),
                "--effort",
                "low",
                "--tools",
                "",
                "--permission-mode",
                "bypassPermissions",
                prompt,
            ],
            cwd=root,
            timeout_seconds=timeout_seconds,
            check=False,
        )
    except subprocess.TimeoutExpired as exc:
        write_text(output_path, ensure_text(exc.stdout).strip() + "\n")
        write_text(log_path, f"TimeoutExpired: {exc}\n{ensure_text(exc.stderr)}\n")
        return {"model": "claude", "status": "timeout", "output_path": str(output_path), "log_path": str(log_path)}

    write_text(output_path, completed.stdout.strip() + "\n")
    write_text(log_path, completed.stderr)

    return {
        "model": "claude",
        "status": "ok" if completed.returncode == 0 else "error",
        "output_path": str(output_path),
        "log_path": str(log_path),
        "exit_code": str(completed.returncode),
    }


def build_comment(
    *,
    pr: dict[str, object],
    run_id: str,
    run_dir: Path,
    results: list[dict[str, str]],
) -> str:
    model_labels = ", ".join(f"`{item['model']}`" for item in results) or "`none`"
    lines = [
        f"<!-- local-pr-review:{pr['number']}:{run_id} -->",
        f"## Local PR Review ({model_labels})",
        "",
        "- mode: local replacement for disabled GitHub Actions review",
        f"- artifact: `{run_dir}`",
        f"- pr: #{pr['number']} {pr['title']}",
        f"- base: `{pr['baseRefName']}`",
        f"- head: `{pr['headRefName']}`",
        "",
    ]

    for item in results:
        output_path = Path(item["output_path"])
        review_text = output_path.read_text(encoding="utf-8").strip() if output_path.exists() else "missing output"
        lines.extend(
            [
                f"### {item['model'].capitalize()}",
                "",
                f"- status: `{item['status']}`",
                f"- artifact: `{output_path}`",
                "",
                review_text or "empty output",
                "",
            ]
        )

    return "\n".join(lines).rstrip() + "\n"


def review_pull_request(
    *,
    root: Path,
    repo: str,
    pr_number: int,
    models: list[str],
    artifact_root: Path,
    post_comment: bool,
    max_focus_files: int,
    max_file_diff_lines: int,
    max_total_diff_lines: int,
    codex_timeout_seconds: int,
    claude_timeout_seconds: int,
) -> Path:
    pr = gh_json(
        root,
        "pr",
        "view",
        str(pr_number),
        "--repo",
        repo,
        "--json",
        "number,title,url,baseRefName,headRefName,files,isDraft",
    )
    if not isinstance(pr, dict):
        raise SystemExit(f"Unexpected PR payload for #{pr_number}")

    base_ref = str(pr["baseRefName"])
    head_ref = str(pr["headRefName"])
    run_id = datetime.now().strftime(f"%Y%m%d-%H%M%S-pr{pr_number}")
    run_dir = artifact_root / run_id
    run_dir.mkdir(parents=True, exist_ok=True)

    run(["git", "fetch", "origin", base_ref, head_ref, "--quiet"], cwd=root)
    diff_range = f"origin/{base_ref}...origin/{head_ref}"

    files = pr.get("files") or []
    if not isinstance(files, list):
        files = []
    changed_files = [str(entry.get("path", "")) for entry in files if str(entry.get("path", ""))]
    if not changed_files:
        changed_files = [line for line in git_output(root, "diff", "--name-only", diff_range).splitlines() if line.strip()]

    diffstat_text = truncate_lines(git_output(root, "diff", "--stat", diff_range), 80)
    focus_files = select_focus_files(files, max_files=max_focus_files)
    focused_diff_text = build_focused_diff(
        root=root,
        diff_range=diff_range,
        focus_files=focus_files,
        max_file_lines=max_file_diff_lines,
        max_total_lines=max_total_diff_lines,
    )

    changed_files_path = run_dir / "changed-files.txt"
    diffstat_path = run_dir / "diffstat.txt"
    focused_diff_path = run_dir / "focused-diff.diff"
    codex_prompt_path = run_dir / "codex-prompt.md"
    claude_prompt_path = run_dir / "claude-prompt.md"
    results_path = run_dir / "results.json"
    comment_path = run_dir / "comment.md"
    summary_path = run_dir / "summary.md"

    write_text(changed_files_path, "\n".join(changed_files).strip() + "\n")
    write_text(diffstat_path, diffstat_text + "\n")
    write_text(focused_diff_path, focused_diff_text + "\n")

    codex_prompt = build_prompt(
        reviewer="codex",
        pr=pr,
        changed_files=changed_files,
        diffstat_text=diffstat_text,
        focused_diff_text=focused_diff_text,
    )
    claude_prompt = build_prompt(
        reviewer="claude",
        pr=pr,
        changed_files=changed_files,
        diffstat_text=diffstat_text,
        focused_diff_text=focused_diff_text,
    )

    write_text(codex_prompt_path, codex_prompt)
    write_text(claude_prompt_path, claude_prompt)

    results: list[dict[str, str]] = []
    for model in models:
        if model == "codex":
            results.append(
                run_codex(
                    root=root,
                    run_dir=run_dir,
                    prompt=codex_prompt,
                    timeout_seconds=codex_timeout_seconds,
                )
            )
        elif model == "claude":
            results.append(
                run_claude(
                    root=root,
                    run_dir=run_dir,
                    prompt=claude_prompt,
                    timeout_seconds=claude_timeout_seconds,
                )
            )

    write_text(results_path, json.dumps(results, ensure_ascii=True, indent=2) + "\n")

    comment_text = build_comment(pr=pr, run_id=run_id, run_dir=run_dir, results=results)
    write_text(comment_path, comment_text)

    summary_lines = [
        "# Local PR Review Summary",
        "",
        f"- run_id: {run_id}",
        f"- repo: {repo}",
        f"- pr_number: {pr['number']}",
        f"- title: {pr['title']}",
        f"- url: {pr['url']}",
        f"- base: {base_ref}",
        f"- head: {head_ref}",
        f"- changed_files: {changed_files_path}",
        f"- diffstat: {diffstat_path}",
        f"- focused_diff: {focused_diff_path}",
        f"- comment: {comment_path}",
        f"- post_comment: {'yes' if post_comment else 'no'}",
        "",
        "## Models",
        "",
    ]
    for item in results:
        summary_lines.extend(
            [
                f"- {item['model']}: {item['status']}",
                f"  - output: {item['output_path']}",
                f"  - log: {item['log_path']}",
            ]
        )
    write_text(summary_path, "\n".join(summary_lines) + "\n")

    if post_comment:
        run(
            [
                "gh",
                "pr",
                "review",
                str(pr_number),
                "--repo",
                repo,
                "--comment",
                "--body-file",
                str(comment_path),
            ],
            cwd=root,
        )

    print(summary_path)
    return summary_path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run local Codex/Claude review for GitHub PRs.")
    parser.add_argument("--pr", dest="prs", action="append", type=int, help="Pull request number to review. Repeatable.")
    parser.add_argument("--repo", help="GitHub repository in OWNER/REPO format. Defaults to origin remote.")
    parser.add_argument(
        "--models",
        default=os.environ.get("ZZIRIT_PR_REVIEW_MODELS", "claude"),
        help="Comma-separated model list. Supported: codex, claude.",
    )
    parser.add_argument("--post-comment", action="store_true", help="Post the review summary to the PR as a review comment.")
    parser.add_argument(
        "--artifact-root",
        default=str(Path(os.environ.get("ZZIRIT_PR_REVIEW_ARTIFACT_ROOT", Path(__file__).resolve().parents[2] / "artifacts" / "pr-review"))),
        help="Artifact output directory.",
    )
    parser.add_argument("--max-focus-files", type=int, default=12)
    parser.add_argument("--max-file-diff-lines", type=int, default=140)
    parser.add_argument("--max-total-diff-lines", type=int, default=1600)
    parser.add_argument("--codex-timeout-seconds", type=int, default=180)
    parser.add_argument("--claude-timeout-seconds", type=int, default=120)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    root = Path(__file__).resolve().parents[2]
    repo = args.repo or parse_repo_from_origin(root)
    models = [item.strip() for item in args.models.split(",") if item.strip()]
    unknown_models = [item for item in models if item not in {"codex", "claude"}]
    if unknown_models:
        raise SystemExit(f"Unsupported models: {', '.join(unknown_models)}")

    prs = args.prs
    if not prs:
        pr_list = gh_json(root, "pr", "list", "--repo", repo, "--state", "open", "--json", "number,isDraft")
        if not isinstance(pr_list, list):
            raise SystemExit("Unexpected pull request list payload")
        prs = [int(item["number"]) for item in pr_list if not item.get("isDraft")]

    if not prs:
        print("No open non-draft pull requests found.")
        return 0

    artifact_root = Path(args.artifact_root)
    artifact_root.mkdir(parents=True, exist_ok=True)

    for pr_number in prs:
        review_pull_request(
            root=root,
            repo=repo,
            pr_number=pr_number,
            models=models,
            artifact_root=artifact_root,
            post_comment=args.post_comment,
            max_focus_files=args.max_focus_files,
            max_file_diff_lines=args.max_file_diff_lines,
            max_total_diff_lines=args.max_total_diff_lines,
            codex_timeout_seconds=args.codex_timeout_seconds,
            claude_timeout_seconds=args.claude_timeout_seconds,
        )

    return 0


if __name__ == "__main__":
    sys.exit(main())
