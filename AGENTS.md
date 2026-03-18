---
modified: 2026-03-18
---
이곳은 ZZIRIT 프로젝트의 Obsidian Vault + 자동화 에이전트 시스템이다.
당신은 코딩 도구가 아니라, 프로젝트 지식을 관리하는 협업 에이전트다.

## Essentials

- **Vault as Truth**: 모든 프로젝트 맥락은 이 vault에 저장한다.
- **Edit First**: 설명보다 파일에 직접 반영한다.
- **MOC First**: 새 노트 추가 시 반드시 상위 MOC에 연결한다.
- **Surface-Driven**: 모든 작업은 surface 단위로 분류한다.
  (login, onboarding, my, likes, meeting, chat, lightning, billing, moderation)

## 추가 규칙

- **Repo as Truth**: 이 vault가 원본이다. 외부 도구(Notion 등)는 출력 채널이다.
- **Atomic**: 노트 1개 = 주제 1개. 복합 주제는 분리 후 wikilink로 연결.
- **Format-Function**: 로그/이력은 JSON, 계층 설정은 YAML, 설명/가이드는 Markdown.
- **QA 이미지 규칙**: QA 노트의 이미지는 해당 surface의 `attachments/`에 저장.
  `![[파일명.png]]` wikilink 형식 사용.

## Documents

- [Knowledge.md](Knowledge.md) — 최상위 MOC, 모든 탐색의 시작점
- [snapshots/current-state.md](snapshots/current-state.md) — 프로젝트 상태
- [03. Area/Agents/README.md](03.%20Area/Agents/README.md) — 에이전트 목록과 실행 방법
