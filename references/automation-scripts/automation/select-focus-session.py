#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import sys
from datetime import datetime, timedelta
from pathlib import Path


DEFAULT_ORDER = [
    "login",
    "onboarding",
    "lightning",
    "meeting",
    "chat",
    "likes",
    "my",
    "automation",
    "server",
]

FOLLOWUP_PRIORITY = [
    "automation",
    "chat",
    "my",
    "onboarding",
    "login",
    "meeting",
    "likes",
]

DEFAULT_TASK_QUEUE = {
    "version": 1,
    "active_task_id": "qa-automation",
    "tasks": [
        {
            "id": "likes",
            "title": "Likes polish and QA",
            "section": "likes",
            "status": "done",
            "required_passes": 1,
            "blocked_threshold": 3,
        },
        {
            "id": "meeting",
            "title": "Meeting polish and QA",
            "section": "meeting",
            "status": "done",
            "required_passes": 1,
            "blocked_threshold": 3,
        },
        {
            "id": "qa-automation",
            "title": "QA automation stabilization",
            "section": "automation",
            "status": "in_progress",
            "required_passes": 2,
            "blocked_threshold": 3,
        },
        {
            "id": "chat",
            "title": "Chat polish and QA",
            "section": "chat",
            "status": "pending",
            "required_passes": 1,
            "blocked_threshold": 3,
        },
    ],
}

SURFACE_SPEC_MANIFEST = Path("/Users/user/zzirit-v2/docs/spec/surfaces/manifest.json")

SECTION_METADATA = {
    "login": {
        "label": "unauthenticated entry/login",
        "goal": "4개 진입 화면과 로그인 시작 플로우를 Figma 기준 85% 수준까지 정리하고 strict 비교/재캡처까지 남긴다.",
    },
    "onboarding": {
        "label": "onboarding",
        "goal": "온보딩 6단계 흐름을 Figma 기준 85% 수준까지 정리하고 핵심 단계별 비교/재캡처를 남긴다.",
    },
    "lightning": {
        "label": "lightning",
        "goal": "번개 홈/카드/필터 레이아웃을 Figma 기준 85% 수준까지 밀고 live path와 visual parity를 함께 맞춘다.",
    },
    "meeting": {
        "label": "meeting",
        "goal": "미팅 목록/상세의 사용자 흐름과 UI를 85% 수준까지 구현하고 최소 smoke를 남긴다.",
    },
    "chat": {
        "label": "chatting",
        "goal": "채팅 목록/채팅방 흐름을 기존 zzirit-rn과 API 계약 기준으로 다시 맞추고 최소 smoke를 남긴다.",
    },
    "likes": {
        "label": "likes",
        "goal": "받은 Like/보낸 Like/ZZIRIT 흐름을 디자인 기준으로 정리하고 언락/preview/review QA까지 닫는다.",
    },
    "my": {
        "label": "MY/likes",
        "goal": "MY 홈과 like 목록을 85% 수준까지 구현하고 프로필/설정 흐름과 연결한다.",
    },
    "automation": {
        "label": "automation/qa",
        "goal": "자동화 루프를 task queue, agent state, result.json, 자동 전환 기준으로 정리해서 끊기지 않는 배치를 만든다.",
    },
    "server": {
        "label": "server/integration",
        "goal": "남은 서버/API 드리프트와 실경로 smoke를 정리하되 UI 배치와 균형을 맞춘다.",
    },
}


def load_state(path: Path) -> dict:
    if not path.exists():
        return {}
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return {}
    return data if isinstance(data, dict) else {}


def parse_time(value: str | None) -> datetime | None:
    if not value:
        return None
    try:
        return datetime.strptime(value, "%Y-%m-%d %H:%M:%S")
    except ValueError:
        return None


def choose_next_section(current: str | None, order: list[str]) -> str:
    if not current or current not in order:
        return order[0]
    index = order.index(current)
    return order[(index + 1) % len(order)]


def parse_bool(value: object) -> bool:
    if isinstance(value, bool):
        return value
    if value is None:
        return False
    return str(value).strip().lower() in {"1", "true", "yes", "y", "on"}


def ensure_task_queue(path: Path) -> dict:
    if not path.exists():
        path.write_text(json.dumps(DEFAULT_TASK_QUEUE, ensure_ascii=True, indent=2) + "\n", encoding="utf-8")
        return json.loads(json.dumps(DEFAULT_TASK_QUEUE))

    data = load_state(path)
    tasks = data.get("tasks") if isinstance(data, dict) else None
    if not isinstance(tasks, list) or not tasks:
        path.write_text(json.dumps(DEFAULT_TASK_QUEUE, ensure_ascii=True, indent=2) + "\n", encoding="utf-8")
        return json.loads(json.dumps(DEFAULT_TASK_QUEUE))
    return data


def normalize_queue_tasks(queue: dict, spec_map: dict[str, dict]) -> dict:
    tasks = queue.get("tasks", [])
    if not isinstance(tasks, list):
        return queue

    valid_sections = set(SECTION_METADATA)
    for task in tasks:
        if not isinstance(task, dict):
            continue
        source_surface = str(task.get("source_surface", "")).strip()
        task_id = str(task.get("id", "")).strip()
        if source_surface and source_surface in valid_sections:
            task["section"] = source_surface
            continue
        if task_id in spec_map and task_id in valid_sections:
            task["section"] = task_id
    return queue


def choose_task_from_queue(queue: dict) -> dict | None:
    tasks = [task for task in queue.get("tasks", []) if isinstance(task, dict)]
    if not tasks:
        return None

    active_task_id = queue.get("active_task_id")
    if active_task_id:
        for task in tasks:
            if task.get("id") == active_task_id and task.get("status") in {"in_progress", "pending", "queued"}:
                return task

    for status in ("in_progress", "pending", "queued"):
        for task in tasks:
            if task.get("status") == status:
                return task

    return None


def load_surface_specs(path: Path) -> dict[str, dict]:
    data = load_state(path)
    surfaces = data.get("surfaces") if isinstance(data, dict) else None
    if not isinstance(surfaces, list):
        return {}
    spec_map: dict[str, dict] = {}
    for item in surfaces:
        if not isinstance(item, dict):
            continue
        surface_id = str(item.get("id", "")).strip()
        if surface_id:
            spec_map[surface_id] = item
    return spec_map


def maybe_append_followup_tasks(queue: dict, spec_map: dict[str, dict], now: datetime) -> dict:
    tasks = [task for task in queue.get("tasks", []) if isinstance(task, dict)]
    if any(task.get("status") in {"in_progress", "pending", "queued"} for task in tasks):
        return queue

    existing_ids = {str(task.get("id", "")).strip() for task in tasks}
    appended = []

    for surface_id in FOLLOWUP_PRIORITY:
        spec = spec_map.get(surface_id, {})
        if not spec:
            continue
        if str(spec.get("current_state", "")).strip() == "blocked":
            continue
        next_step = str(spec.get("next_step", "")).strip()
        if not next_step:
            continue

        task_id = f"{surface_id}-followup"
        if task_id in existing_ids:
            continue

        section = surface_id if surface_id in SECTION_METADATA else surface_id
        title = f"{surface_id.replace('-', ' ').title()} follow-up"
        appended.append(
            {
                "id": task_id,
                "title": title,
                "section": section,
                "status": "pending",
                "required_passes": 1,
                "blocked_threshold": 3,
                "source_surface": surface_id,
                "source_next_step": next_step,
                "created_at": now.strftime("%Y-%m-%d %H:%M:%S"),
            }
        )
        existing_ids.add(task_id)

    if appended:
        queue.setdefault("tasks", []).extend(appended)

    for task in queue.get("tasks", []):
        if isinstance(task, dict) and task.get("status") == "pending":
            task["status"] = "in_progress"
            task.setdefault("started_at", now.strftime("%Y-%m-%d %H:%M:%S"))
            queue["active_task_id"] = task.get("id")
            break

    return queue


def build_surface_spec_payload(section: str, spec_map: dict[str, dict]) -> dict[str, object]:
    spec = spec_map.get(section, {})
    spec_path = SURFACE_SPEC_MANIFEST.parent / f"{section}.md"
    return {
        "surface_spec_manifest": str(SURFACE_SPEC_MANIFEST),
        "surface_spec_path": str(spec_path) if spec_path.exists() else "",
        "surface_spec_status": spec.get("spec_status", ""),
        "surface_qa_level": spec.get("qa_level", ""),
        "surface_automation_status": spec.get("automation_status", ""),
        "surface_current_state": spec.get("current_state", ""),
        "surface_next_step": spec.get("next_step", ""),
    }


def main() -> int:
    state_path = Path(sys.argv[1])
    duration_minutes = int(sys.argv[2])
    now = datetime.now()
    state = load_state(state_path)
    queue_path = state_path.parent / "task-queue.json"
    agent_state_path = state_path.parent / "agent-state.json"
    next_action_path = state_path.parent / "next-action.md"
    spec_map = load_surface_specs(SURFACE_SPEC_MANIFEST)
    queue = ensure_task_queue(queue_path)
    queue = normalize_queue_tasks(queue, spec_map)
    queue = maybe_append_followup_tasks(queue, spec_map, now)
    queue_path.write_text(json.dumps(queue, ensure_ascii=True, indent=2) + "\n", encoding="utf-8")
    order = DEFAULT_ORDER

    queued_task = choose_task_from_queue(queue)
    if queued_task and queued_task.get("section") in SECTION_METADATA:
        section = queued_task["section"]
        metadata = SECTION_METADATA[section]
        current_task_id = state.get("task_id")
        started_at = parse_time(state.get("started_at")) if current_task_id == queued_task.get("id") else now
        if not started_at:
            started_at = now
        expires_at = now + timedelta(minutes=duration_minutes)
        payload = {
            "section": section,
            "label": metadata["label"],
            "goal": metadata["goal"],
            "started_at": started_at.strftime("%Y-%m-%d %H:%M:%S"),
            "expires_at": expires_at.strftime("%Y-%m-%d %H:%M:%S"),
            "target": "85%",
            "pinned": True,
            "task_id": queued_task.get("id", ""),
            "task_title": queued_task.get("title", queued_task.get("id", "")),
            "task_status": queued_task.get("status", "pending"),
            "task_queue_file": str(queue_path),
            "agent_state_file": str(agent_state_path),
            "next_action_file": str(next_action_path),
            **build_surface_spec_payload(section, spec_map),
        }
        state_path.write_text(json.dumps(payload, ensure_ascii=True, indent=2) + "\n", encoding="utf-8")
        print(json.dumps(payload, ensure_ascii=True))
        return 0

    current_section = state.get("section")
    started_at = parse_time(state.get("started_at"))
    expires_at = parse_time(state.get("expires_at"))
    pinned = parse_bool(state.get("pinned")) or parse_bool(
        os.environ.get("ZZIRIT_AUTOMATION_PIN_FOCUS_SECTION")
    )

    keep_current = bool(
        current_section
        and current_section in SECTION_METADATA
        and started_at
        and expires_at
        and (pinned or now < expires_at)
    )

    section = current_section if keep_current else choose_next_section(current_section, order)
    if not keep_current:
        started_at = now
        expires_at = now + timedelta(minutes=duration_minutes)

    metadata = SECTION_METADATA[section]
    payload = {
        "section": section,
        "label": metadata["label"],
        "goal": metadata["goal"],
        "started_at": started_at.strftime("%Y-%m-%d %H:%M:%S"),
        "expires_at": expires_at.strftime("%Y-%m-%d %H:%M:%S"),
        "target": "85%",
        "pinned": pinned,
        **build_surface_spec_payload(section, spec_map),
    }
    state_path.write_text(json.dumps(payload, ensure_ascii=True, indent=2) + "\n", encoding="utf-8")

    print(json.dumps(payload, ensure_ascii=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
