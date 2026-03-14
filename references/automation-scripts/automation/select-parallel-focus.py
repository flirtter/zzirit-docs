#!/usr/bin/env python3
from __future__ import annotations

import json
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
        "goal": "자동화 루프와 QA 복구 경로를 정리하되 메인 focus를 방해하지 않는 범위에서 기계 readable 상태를 남긴다.",
    },
    "server": {
        "label": "server/integration",
        "goal": "남은 서버/API 드리프트와 실경로 smoke를 정리하되 UI 배치와 균형을 맞춘다.",
    },
}

SURFACE_SPEC_MANIFEST = Path("/Users/user/zzirit-v2/docs/spec/surfaces/manifest.json")


def load_state(path: Path) -> dict:
    if not path.exists():
        return {}
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return {}
    return data if isinstance(data, dict) else {}


def choose_next_section(previous: str | None, exclude: str | None) -> str:
    candidates = [section for section in DEFAULT_ORDER if section != exclude]
    if not candidates:
        return DEFAULT_ORDER[0]
    if previous in candidates:
        index = candidates.index(previous)
        return candidates[(index + 1) % len(candidates)]
    return candidates[0]


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
    if len(sys.argv) < 3:
        raise SystemExit("usage: select-parallel-focus.py <state-path> <active-focus> [duration-minutes]")

    state_path = Path(sys.argv[1])
    active_focus = sys.argv[2] or None
    duration_minutes = int(sys.argv[3]) if len(sys.argv) > 3 else 45

    now = datetime.now()
    state = load_state(state_path)
    spec_map = load_surface_specs(SURFACE_SPEC_MANIFEST)
    previous_section = state.get("section")
    section = choose_next_section(previous_section, active_focus)
    metadata = SECTION_METADATA[section]

    payload = {
        "section": section,
        "label": metadata["label"],
        "goal": metadata["goal"],
        "target": "85%",
        "started_at": now.strftime("%Y-%m-%d %H:%M:%S"),
        "expires_at": (now + timedelta(minutes=duration_minutes)).strftime("%Y-%m-%d %H:%M:%S"),
        "active_codex_focus": active_focus or "none",
        **build_surface_spec_payload(section, spec_map),
    }
    state_path.write_text(json.dumps(payload, ensure_ascii=True, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(payload, ensure_ascii=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
