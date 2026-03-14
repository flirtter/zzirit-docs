#!/usr/bin/env python3
from __future__ import annotations

import json
import shlex
import subprocess
from pathlib import Path
from typing import Any


MEMORY_ROOT = Path("/Users/user/zzirit-memory-hub")
SNAPSHOT_ROOT = MEMORY_ROOT / "snapshots"
AUTOMATION_NOTE_ROOT = SNAPSHOT_ROOT / "automation-run-notes"
ZZIRIT_V2_ROOT = Path("/Users/user/zzirit-v2")
ZZIRIT_PROXY_ROOT = Path("/Users/user/zzirit-proxy")
REMOTE_ROOT = "/Users/user/zzirit-v2"
SURFACE_SPEC_ROOT = ZZIRIT_V2_ROOT / "docs/spec/surfaces"
SURFACE_MANIFEST = SURFACE_SPEC_ROOT / "manifest.json"

REMOTE_LATEST_PREFIXES = {
    "chat_host_qa": "chat-host-qa-",
    "meeting_host_qa": "meeting-host-qa-",
    "my_host_qa": "my-host-qa-",
    "likes_host_qa": "likes-host-qa-",
    "likes_release": "likes-release-",
    "chat_release": "chat-release-",
}

REMOTE_ARTIFACT_DIRS = {
    "appium_onboarding": "artifacts/appium-onboarding",
    "appium_likes": "artifacts/appium-likes",
    "appium_meeting": "artifacts/appium-meeting",
    "appium_chat": "artifacts/appium-chat",
}


def run(cmd: list[str], cwd: Path | None = None, timeout: int = 30) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        cmd,
        cwd=str(cwd) if cwd else None,
        capture_output=True,
        text=True,
        timeout=timeout,
    )


def run_remote(command: str, timeout: int = 30) -> subprocess.CompletedProcess[str]:
    return run(["ssh", "studio", command], timeout=timeout)


def run_remote_python(code: str, timeout: int = 30) -> subprocess.CompletedProcess[str]:
    return run_remote(f"python3 -c {shlex.quote(code)}", timeout=timeout)


def safe_json_load(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {}
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return {}
    return payload if isinstance(payload, dict) else {}


def ensure_dirs() -> None:
    for path in [
        SNAPSHOT_ROOT,
        SNAPSHOT_ROOT / "git",
        SNAPSHOT_ROOT / "state",
        SNAPSHOT_ROOT / "surfaces",
        AUTOMATION_NOTE_ROOT,
    ]:
        path.mkdir(parents=True, exist_ok=True)


def collect_git_repo(repo_root: Path) -> dict[str, Any]:
    name = repo_root.name
    branch = run(["git", "branch", "--show-current"], cwd=repo_root).stdout.strip()
    head = run(["git", "rev-parse", "HEAD"], cwd=repo_root).stdout.strip()
    remotes = run(["git", "remote", "-v"], cwd=repo_root).stdout.strip().splitlines()
    status = run(["git", "status", "--short"], cwd=repo_root).stdout.splitlines()
    commits = run(
        ["git", "log", "--reverse", "--format=%h %ad %s", "--date=short"],
        cwd=repo_root,
        timeout=60,
    ).stdout.splitlines()
    recent = run(["git", "log", "--oneline", "--decorate", "-n", "30"], cwd=repo_root).stdout.splitlines()
    return {
        "name": name,
        "path": str(repo_root),
        "branch": branch,
        "head": head,
        "remotes": remotes,
        "status": status,
        "commits": commits,
        "recent_commits": recent,
    }


def read_remote_file(rel_path: str) -> str:
    result = run_remote(f"cat {shlex.quote(f'{REMOTE_ROOT}/{rel_path}')}", timeout=20)
    if result.returncode != 0:
        return ""
    return result.stdout


def read_remote_json(rel_path: str) -> dict[str, Any]:
    raw = read_remote_file(rel_path)
    if not raw.strip():
        return {}
    try:
        payload = json.loads(raw)
    except json.JSONDecodeError:
        return {}
    return payload if isinstance(payload, dict) else {}


def read_remote_text(rel_path: str) -> str:
    return read_remote_file(rel_path)


def latest_remote_dir(prefix: str) -> str:
    code = (
        "from pathlib import Path; "
        "root=Path('/Users/user/zzirit-v2/artifacts/manual-review'); "
        f"dirs=sorted([p for p in root.iterdir() if p.is_dir() and p.name.startswith('{prefix}')]); "
        "print(dirs[-1] if dirs else '')"
    )
    result = run_remote_python(code, timeout=20)
    return result.stdout.strip()


def latest_remote_subdirs(rel_path: str, limit: int = 5) -> list[str]:
    code = (
        "from pathlib import Path; "
        f"root=Path('{REMOTE_ROOT}/{rel_path}'); "
        "dirs=sorted([p for p in root.iterdir() if p.is_dir()]); "
        f"print('\\n'.join(str(p) for p in dirs[-{limit}:]))"
    )
    result = run_remote_python(code, timeout=20)
    if result.returncode != 0:
        return []
    return [line for line in result.stdout.splitlines() if line.strip()]


def latest_remote_automation_note_paths(limit: int = 5) -> list[str]:
    code = (
        "from pathlib import Path; "
        "root=Path('/Users/user/zzirit-v2/artifacts/automation/runs'); "
        "notes=sorted([p/'memory-hub-note.md' for p in root.iterdir() if p.is_dir() and (p/'memory-hub-note.md').exists()]); "
        f"print('\\n'.join(str(p) for p in notes[-{limit}:]))"
    )
    result = run_remote_python(code, timeout=20)
    if result.returncode != 0:
        return []
    return [line for line in result.stdout.splitlines() if line.strip()]


def copy_remote_file(remote_abs_path: str, local_path: Path) -> None:
    result = run_remote(f"cat {shlex.quote(remote_abs_path)}", timeout=30)
    if result.returncode != 0:
        return
    local_path.parent.mkdir(parents=True, exist_ok=True)
    local_path.write_text(result.stdout, encoding="utf-8")


def sync_remote_automation_notes() -> list[str]:
    note_paths = latest_remote_automation_note_paths()
    copied: list[str] = []
    for remote_note in note_paths:
        run_id = Path(remote_note).parent.name
        local_md = AUTOMATION_NOTE_ROOT / f"{run_id}.md"
        local_json = AUTOMATION_NOTE_ROOT / f"{run_id}.json"
        copy_remote_file(remote_note, local_md)
        copy_remote_file(str(Path(remote_note).with_suffix(".json")), local_json)
        if local_md.exists():
            copied.append(str(local_md))
    return copied


def collect_remote_identity() -> dict[str, str]:
    result = run_remote("hostname; whoami; sw_vers -productName; sw_vers -productVersion", timeout=20)
    if result.returncode != 0:
        return {
            "connection_status": "failed",
            "host": "unknown",
            "user": "unknown",
            "macos_name": "unknown",
            "macos_version": "unknown",
        }
    lines = [line.strip() for line in result.stdout.splitlines() if line.strip()]
    return {
        "connection_status": "ok",
        "host": lines[0] if len(lines) > 0 else "unknown",
        "user": lines[1] if len(lines) > 1 else "unknown",
        "macos_name": lines[2] if len(lines) > 2 else "unknown",
        "macos_version": lines[3] if len(lines) > 3 else "unknown",
    }


def collect_remote_state() -> dict[str, Any]:
    identity = collect_remote_identity()
    repo_state = {
        "task_queue": read_remote_json("artifacts/automation/task-queue.json"),
        "agent_state": read_remote_json("artifacts/automation/agent-state.json"),
        "next_action_md": read_remote_text("artifacts/automation/next-action.md"),
        "status_md": read_remote_text("artifacts/automation/status.md"),
        "health_md": read_remote_text("artifacts/automation/health.md"),
    }
    latest_manual = {name: latest_remote_dir(prefix) for name, prefix in REMOTE_LATEST_PREFIXES.items()}
    latest_appium = {name: latest_remote_subdirs(path) for name, path in REMOTE_ARTIFACT_DIRS.items()}
    latest_notes = sync_remote_automation_notes()
    return {
        **identity,
        "repo_root": REMOTE_ROOT,
        "automation": repo_state,
        "latest_manual_review_dirs": latest_manual,
        "latest_appium_dirs": latest_appium,
        "latest_automation_notes": latest_notes,
    }


def collect_surface_specs() -> dict[str, Any]:
    manifest = safe_json_load(SURFACE_MANIFEST)
    specs = {}
    for path in sorted(SURFACE_SPEC_ROOT.glob("*.md")):
        specs[path.stem] = path.read_text(encoding="utf-8")
    return {"manifest": manifest, "specs": specs}


def build_current_state(v2: dict[str, Any], proxy: dict[str, Any], remote: dict[str, Any], surfaces: dict[str, Any]) -> dict[str, Any]:
    return {
        "generated_at": run(["date", "+%Y-%m-%d %H:%M:%S %Z"]).stdout.strip(),
        "memory_repo": str(MEMORY_ROOT),
        "repositories": {
            "zzirit_v2": {k: v for k, v in v2.items() if k != "commits"},
            "zzirit_proxy": {k: v for k, v in proxy.items() if k != "commits"},
        },
        "remote_mac_studio": remote,
        "surfaces": surfaces["manifest"],
    }


def write_json(path: Path, payload: dict[str, Any]) -> None:
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def write_text(path: Path, content: str) -> None:
    path.write_text(content, encoding="utf-8")


def render_repositories_md(v2: dict[str, Any], proxy: dict[str, Any]) -> str:
    def section(title: str, payload: dict[str, Any]) -> str:
        lines = [f"## {title}", ""]
        lines.append(f"- path: `{payload['path']}`")
        lines.append(f"- branch: `{payload['branch']}`")
        lines.append(f"- head: `{payload['head']}`")
        lines.append("- remotes:")
        lines.extend([f"  - `{line}`" for line in payload["remotes"]] or ["  - none"])
        lines.append("- worktree_status:")
        lines.extend([f"  - `{line}`" for line in payload["status"][:80]] or ["  - clean"])
        lines.append("")
        lines.append("### Recent commits")
        lines.extend([f"- `{line}`" for line in payload["recent_commits"][:30]])
        lines.append("")
        return "\n".join(lines)

    return "\n".join(
        [
            "# Repositories",
            "",
            section("zzirit-v2", v2),
            section("zzirit-proxy", proxy),
        ]
    )


def render_commits_md(title: str, commits: list[str]) -> str:
    return "\n".join([f"# {title}", ""] + [f"- `{line}`" for line in commits]) + "\n"


def render_surface_status_md(surfaces: dict[str, Any]) -> str:
    manifest = surfaces.get("manifest", {})
    rows = [
        "# Surface Status",
        "",
        "| id | qa_level | automation_status | current_state | next_step |",
        "| --- | --- | --- | --- | --- |",
    ]
    for item in manifest.get("surfaces", []):
        if not isinstance(item, dict):
            continue
        rows.append(
            f"| {item.get('id','')} | {item.get('qa_level','')} | {item.get('automation_status','')} | {item.get('current_state','')} | {str(item.get('next_step','')).replace('|','/')} |"
        )
    rows.append("")
    rows.append("## Current spec files")
    for name in sorted(surfaces.get("specs", {})):
        rows.append(f"- `{name}`")
    rows.append("")
    return "\n".join(rows)


def render_automation_state_md(remote: dict[str, Any]) -> str:
    automation = remote.get("automation", {})
    lines = [
        "# Automation State",
        "",
        f"- connection_status: `{remote.get('connection_status','')}`",
        f"- remote_host: `{remote.get('host','')}`",
        f"- remote_user: `{remote.get('user','')}`",
        f"- remote_macos: `{remote.get('macos_name','')} {remote.get('macos_version','')}`",
        f"- remote_repo_root: `{remote.get('repo_root','')}`",
        "",
        "## Status.md",
        "```md",
        automation.get("status_md", "").strip(),
        "```",
        "",
        "## Health.md",
        "```md",
        automation.get("health_md", "").strip(),
        "```",
        "",
        "## Next Action",
        "```md",
        automation.get("next_action_md", "").strip(),
        "```",
        "",
        "## Latest artifact roots",
    ]
    for key, value in remote.get("latest_manual_review_dirs", {}).items():
        lines.append(f"- {key}: `{value or 'missing'}`")
    for key, values in remote.get("latest_appium_dirs", {}).items():
        preview = ", ".join(f"`{v}`" for v in values) if values else "`missing`"
        lines.append(f"- {key}: {preview}")
    lines.append("")
    lines.append("## Latest automation run notes")
    for value in remote.get("latest_automation_notes", []):
        lines.append(f"- `{value}`")
    lines.append("")
    return "\n".join(lines)


def render_qa_status_md(remote: dict[str, Any]) -> str:
    lines = [
        "# QA Status",
        "",
        "## Latest remote host QA / release artifacts",
    ]
    for key, value in remote.get("latest_manual_review_dirs", {}).items():
        lines.append(f"- {key}: `{value or 'missing'}`")
    lines.append("")
    lines.append("## Latest remote Appium directories")
    for key, values in remote.get("latest_appium_dirs", {}).items():
        lines.append(f"- {key}:")
        if values:
            lines.extend([f"  - `{item}`" for item in values])
        else:
            lines.append("  - `missing`")
    lines.append("")
    lines.append("## Latest automation run notes")
    for value in remote.get("latest_automation_notes", []):
        lines.append(f"- `{value}`")
    lines.append("")
    return "\n".join(lines)


def render_current_state_md(current: dict[str, Any]) -> str:
    repos = current["repositories"]
    remote = current["remote_mac_studio"]
    lines = [
        "# Current State",
        "",
        f"- generated_at: `{current.get('generated_at','')}`",
        f"- memory_repo: `{current.get('memory_repo','')}`",
        "",
        "## Active repositories",
        f"- zzirit-v2: `{repos['zzirit_v2']['branch']}` @ `{repos['zzirit_v2']['head'][:12]}`",
        f"- zzirit-proxy: `{repos['zzirit_proxy']['branch']}` @ `{repos['zzirit_proxy']['head'][:12]}`",
        "",
        "## Remote automation",
        f"- host: `{remote.get('host','')}`",
        f"- connection_status: `{remote.get('connection_status','')}`",
        f"- macOS: `{remote.get('macos_name','')} {remote.get('macos_version','')}`",
        f"- current_task: `{remote.get('automation',{}).get('task_queue',{}).get('active_task_id','')}`",
        "",
        "## Latest QA artifacts",
    ]
    for key, value in remote.get("latest_manual_review_dirs", {}).items():
        lines.append(f"- {key}: `{value or 'missing'}`")
    for key, values in remote.get("latest_appium_dirs", {}).items():
        preview = ", ".join(f"`{value}`" for value in values[:2]) if values else "`missing`"
        lines.append(f"- {key}: {preview}")
    lines.append("")
    lines.append("## Latest automation run notes")
    for value in remote.get("latest_automation_notes", []):
        lines.append(f"- `{value}`")
    lines.extend(
        [
            "",
        "## Surface snapshot",
        ]
    )
    for item in current.get("surfaces", {}).get("surfaces", []):
        if not isinstance(item, dict):
            continue
        lines.append(
            f"- `{item.get('id','')}`: state=`{item.get('current_state','')}`, qa=`{item.get('qa_level','')}`, automation=`{item.get('automation_status','')}`"
        )
    lines.append("")
    return "\n".join(lines)


def render_issue_backlog_md(current: dict[str, Any]) -> str:
    remote = current.get("remote_mac_studio", {})
    automation = remote.get("automation", {})
    queue = automation.get("task_queue", {})
    tasks = queue.get("tasks", [])
    lines = [
        "# Issue Backlog",
        "",
        "자동화 큐와 surface spec 기준으로 지금 바로 GitHub 이슈로 옮길 수 있는 작업 목록이다.",
        "",
    ]
    for task in tasks:
        if not isinstance(task, dict):
            continue
        task_id = task.get("id", "")
        title = task.get("title", "")
        section = task.get("section", "")
        status = task.get("status", "")
        next_step = task.get("source_next_step", "")
        lines.append(f"## {task_id}")
        lines.append("")
        lines.append(f"- title: `{title}`")
        lines.append(f"- section: `{section}`")
        lines.append(f"- queue_status: `{status}`")
        if next_step:
            lines.append(f"- follow_up_goal: `{next_step}`")
        lines.append("")
    return "\n".join(lines) + "\n"


def extract_spec_section(spec_text: str, heading: str) -> list[str]:
    lines = spec_text.splitlines()
    capture = False
    collected: list[str] = []
    heading_prefix = f"## {heading}"
    for line in lines:
        if line.strip() == heading_prefix:
            capture = True
            continue
        if capture and line.startswith("## "):
            break
        if capture:
            if line.strip():
                collected.append(line.rstrip())
    return collected


def render_issue_backlog_detailed_md(current: dict[str, Any], surfaces: dict[str, Any]) -> str:
    remote = current.get("remote_mac_studio", {})
    automation = remote.get("automation", {})
    queue = automation.get("task_queue", {})
    tasks = queue.get("tasks", [])
    spec_texts = surfaces.get("specs", {})
    lines = [
        "# Detailed Issue Backlog",
        "",
        "자동화 큐와 surface spec을 합쳐, 실제 이슈를 더 잘게 나눌 수 있도록 만든 세부 backlog다.",
        "",
    ]
    for task in tasks:
        if not isinstance(task, dict):
            continue
        if task.get("status") not in {"in_progress", "pending"}:
            continue
        section = task.get("section", "")
        spec_text = spec_texts.get(section, "")
        lines.append(f"## {task.get('id','')}")
        lines.append("")
        lines.append(f"- title: `{task.get('title','')}`")
        lines.append(f"- section: `{section}`")
        lines.append(f"- queue_status: `{task.get('status','')}`")
        if task.get("source_next_step"):
            lines.append(f"- follow_up_goal: `{task.get('source_next_step','')}`")
        for heading in ["Canonical Routes", "Canonical Subroutes", "Canonical Tabs", "Canonical Flow", "Known Gaps", "Done Criteria"]:
            extracted = extract_spec_section(spec_text, heading)
            if not extracted:
                continue
            lines.append("")
            lines.append(f"### {heading}")
            lines.extend(extracted)
        lines.append("")
    return "\n".join(lines)


def main() -> int:
    ensure_dirs()

    v2 = collect_git_repo(ZZIRIT_V2_ROOT)
    proxy = collect_git_repo(ZZIRIT_PROXY_ROOT)
    remote = collect_remote_state()
    surfaces = collect_surface_specs()
    current = build_current_state(v2, proxy, remote, surfaces)

    write_json(SNAPSHOT_ROOT / "current-state.json", current)
    write_text(SNAPSHOT_ROOT / "current-state.md", render_current_state_md(current))
    write_text(SNAPSHOT_ROOT / "repositories.md", render_repositories_md(v2, proxy))
    write_text(SNAPSHOT_ROOT / "surface-status.md", render_surface_status_md(surfaces))
    write_text(SNAPSHOT_ROOT / "automation-state.md", render_automation_state_md(remote))
    write_text(SNAPSHOT_ROOT / "qa-status.md", render_qa_status_md(remote))
    write_text(SNAPSHOT_ROOT / "issue-backlog.md", render_issue_backlog_md(current))
    write_text(SNAPSHOT_ROOT / "issue-backlog-detailed.md", render_issue_backlog_detailed_md(current, surfaces))
    write_text(SNAPSHOT_ROOT / "git" / "zzirit-v2-commits.md", render_commits_md("zzirit-v2 Commits", v2["commits"]))
    write_text(SNAPSHOT_ROOT / "git" / "zzirit-proxy-commits.md", render_commits_md("zzirit-proxy Commits", proxy["commits"]))

    print(SNAPSHOT_ROOT)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
