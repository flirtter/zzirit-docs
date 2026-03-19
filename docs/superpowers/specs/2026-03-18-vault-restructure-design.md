# ZZIRIT Memory Hub → Obsidian Vault + Claude Code Harness

**Date**: 2026-03-18
**Status**: Approved
**Approach**: D (Hybrid) — 경량 Obsidian vault + Claude Code 하네스, 점진적 확장

---

## 1. 배경

ZZIRIT 프로젝트는 3개 레포로 구성:
- `zzirit-docs` — 운영/맥락 레포 (스냅샷, surface specs, 에이전트 정의)
- `zzirit-api` — Flask API (Firestore, Cloud Run)
- `zzirit-rn` — Expo+RN 모임 매칭 앱

현재 zzirit-docs는 잘 구조화되어 있으나:
- CLAUDE.md 없음 → 매 세션마다 컨텍스트 설명 반복
- Obsidian 미설정 → 지식 탐색 UX가 GitHub 의존
- 스킬 없음 → 반복 작업(상태 갱신, handover, QA 집계) 수동
- 디자이너/기획자 참여 경로 없음

## 2. 목표

- zzirit-docs를 Obsidian vault로 업그레이드 (PARA 구조)
- Claude Code 하네스(CLAUDE.md, 스킬, hooks) 추가
- 기획자/디자이너 QA 이미지 워크플로우 제공
- 기존 자산(agents, specs, snapshots, scripts) 100% 보존
- zzirit-api, zzirit-rn 레포는 일절 수정하지 않음

## 3. 제약

- 1인 개발 → 추후 디자이너/기획자 합류 예정
- Phase 1은 최소 구축, Phase 2에서 팀 기능 확장
- 기존 에이전트 정의(agents/) 구조 보존
- 기존 scripts/, .github/ 동작 보존

---

## 4. 폴더 구조

```
zzirit-docs/                    ← Obsidian vault root
├── CLAUDE.md                         ← Claude Code 진입점
├── AGENTS.md                         ← 에이전트 행동 규칙
├── Knowledge.md                      ← 최상위 MOC
│
├── 00. Inbox/                        ← 미분류 자료
│
├── 01. Journal/                      ← 세션 기록
│   ├── handovers/                    ← HANDOVER_*.md
│   ├── workplans/                    ← WORKPLAN_*.md
│   └── qa-reports/                   ← QA_*.md
│
├── 02. Project/                      ← surface별 프로젝트
│   ├── 02. Project.md                ← 칸반 보드
│   ├── login/
│   │   ├── login.md                  ← surface MOC (기존 spec 승격)
│   │   ├── QA/
│   │   │   └── QA.md                 ← QA 대시보드
│   │   └── attachments/              ← QA 이미지
│   ├── onboarding/
│   ├── my/
│   ├── likes/
│   ├── meeting/
│   ├── chat/
│   ├── lightning/
│   ├── billing/
│   └── moderation/
│
├── 03. Area/                         ← 영구 관리 영역
│   ├── Architecture/                 ← API/RN/Proxy 아키텍처
│   ├── Design/                       ← figma-exports + manual-design
│   │   ├── DESIGN-MAP.md
│   │   ├── screens/                  ← Git LFS
│   │   ├── flows/
│   │   └── manual/
│   ├── Database/                     ← schemas/
│   ├── Agents/                       ← agents/ 보존
│   ├── Decisions/                    ← ADR
│   └── Playbooks/                    ← playbooks/
│
├── 04. Resources/                    ← 참고 자료
│   ├── automation-scripts/
│   └── external/
│
├── 05. Archive/                      ← 완료 프로젝트
│
├── 99. Templates/                    ← 노트 템플릿
│   ├── Surface Project.md
│   ├── Handover.md
│   ├── QA Issue.md
│   ├── QA Report.md
│   └── Decision Record.md
│
├── .obsidian/                        ← Obsidian 설정
│   ├── app.json
│   ├── appearance.json
│   └── community-plugins.json
│
├── .claude/
│   ├── settings.json
│   └── skills/
│       ├── refresh/SKILL.md
│       ├── wrap-session/SKILL.md
│       ├── next-task/SKILL.md
│       ├── qa-review/SKILL.md
│       ├── qa-dashboard/SKILL.md
│       ├── capture-decision/SKILL.md
│       └── update-surface/SKILL.md
│
├── scripts/                          ← 기존 보존
├── .github/                          ← 기존 보존
├── snapshots/                        ← 기존 보존 (점진적 마이그레이션)
├── GEMINI.md                         ← 기존 보존
└── PUBLISHING.md                     ← 기존 보존
```

### 기존 자산 매핑

| 기존 위치 | 새 위치 | 처리 |
|-----------|---------|------|
| `snapshots/HANDOVER_*.md` | `01. Journal/handovers/` | 이동 |
| `snapshots/WORKPLAN_*.md` | `01. Journal/workplans/` | 이동 |
| `snapshots/QA_*.md` | `01. Journal/qa-reports/` | 이동 |
| `snapshots/surface-status.md` | `02. Project/02. Project.md`에서 참조 | 링크 |
| `snapshots/current-state.md` | `snapshots/` 유지, Knowledge.md에서 링크 | 유지 |
| `snapshots/automation-state.md` | `snapshots/` 유지 | 유지 |
| `snapshots/issue-backlog.md` | `snapshots/` 유지 | 유지 |
| `references/surface-specs/*.md` | `02. Project/{surface}/{surface}.md` | 이동+승격 |
| `references/figma-exports/` | `03. Area/Design/` | 이동 |
| `references/manual-design/` | `03. Area/Design/manual/` | 이동+중복제거 |
| `references/automation-scripts/` | `04. Resources/automation-scripts/` | 이동 |
| `agents/` | `03. Area/Agents/` | 이동 |
| `schemas/` | `03. Area/Database/` | 이동 |
| `playbooks/` | `03. Area/Playbooks/` | 이동 |
| `scripts/` | `scripts/` | 유지 |
| `.github/` | `.github/` | 유지 |
| `GEMINI.md` | 루트 유지 | 유지 |

---

## 5. QA 이미지 워크플로우

### QA Issue 템플릿

```markdown
---
surface:          ← login | onboarding | my | likes | meeting | chat | lightning
type: qa
reporter:
status: open      ← open | confirmed | fixed | wontfix
severity:         ← critical | major | minor | cosmetic
device:
created: {{date}}
---

## 무엇이 문제인가

(한 줄 설명)

## 스크린샷

### 현재 구현 (문제 화면)
![[{이미지파일}.png]]

### 기대하는 모습 (디자인 시안)
![[{이미지파일}-design.png]]

## 재현 경로

1. 앱 실행
2. →
3. →

## 비고
```

### 디자이너/기획자 흐름

1. Obsidian 열기 → `02. Project/{surface}/QA/` 이동
2. 새 노트 → QA Issue 템플릿 선택
3. 스크린샷 드래그 앤 드롭 (attachments/에 자동 저장)
4. frontmatter 채우기 (Properties UI로 드롭다운)
5. 저장 → Obsidian Git 플러그인으로 자동 push

### Claude Code QA 스킬

- `qa-review {surface}`: open QA 노트 수집 → 이미지 비교 분석 → 갭 리포트
- `qa-dashboard`: 전체 surface QA 집계 테이블

---

## 6. Claude Code 하네스

### CLAUDE.md

- vault 성격 정의 (코드 레포가 아닌 운영/맥락 허브)
- 컨텍스트 로드 순서 (Knowledge.md → current-state → 칸반)
- 핵심 규칙 (MOC 링크 필수, surface 기반 분류, QA 이미지 경로)
- 에이전트 정의 참조 (03. Area/Agents/)

### 스킬 (Phase 1)

| 스킬 | 트리거 | 동작 |
|------|--------|------|
| refresh | "상태 갱신해줘" | refresh_snapshot.py → 갱신 → 요약 → 커밋 |
| wrap-session | "세션 마무리해줘" | diff 분석 → handover 생성 → TODO 정리 |
| next-task | "다음 뭐해?" | backlog + status + 블로커 → 추천 |
| qa-review | "QA 리뷰해줘 {surface}" | open QA 수집 → 이미지 비교 → 리포트 |
| qa-dashboard | "QA 현황" | 전체 surface QA 집계 |
| capture-decision | "결정 기록해줘" | ADR 생성 → Decisions/ 저장 |
| update-surface | "{surface} 상태 업데이트" | spec + status + 칸반 동시 갱신 |

### Hooks

| Hook | 시점 | 동작 |
|------|------|------|
| session-briefing.js | SessionStart | 마지막 handover 이후 변경 요약 + QA open 건수 |
| check-moc-link.js | PostToolUse(Edit/Write) | 새 .md가 MOC에 링크 안 되면 경고 |

### settings.json

```json
{
  "hooks": {
    "SessionStart": [{
      "hooks": [{"type": "command", "command": "node .claude/hooks/session-briefing.js"}]
    }],
    "PostToolUse": [{
      "matcher": "Edit|Write",
      "hooks": [{"type": "command", "command": "node .claude/hooks/check-moc-link.js"}]
    }]
  },
  "permissions": {
    "allow": [
      "Bash(git:*)", "Bash(python3:*)", "Bash(node:*)",
      "Bash(ls:*)", "Bash(find:*)", "Bash(mkdir:*)", "Bash(cp:*)", "Bash(mv:*)"
    ]
  }
}
```

---

## 7. Obsidian 설정

### 필수 플러그인

| 플러그인 | 용도 |
|---------|------|
| Obsidian Git | 자동 commit & push (비개발자용) |
| Templater | 템플릿 변수 자동 채움 |
| Folder Notes | 폴더 클릭 → MOC 열기 |
| Kanban | QA, 프로젝트 칸반 보드 |
| Dataview | 메타데이터 기반 동적 쿼리 |

### Git LFS

`03. Area/Design/screens/` 와 `03. Area/Design/manual/` 의 이미지 파일은 Git LFS로 관리.

```
*.png filter=lfs diff=lfs merge=lfs -text
*.jpg filter=lfs diff=lfs merge=lfs -text
```

---

## 8. Phase 계획

### Phase 1 (지금, 1인)
- PARA 폴더 구조 생성 + 기존 자산 재배치
- CLAUDE.md, AGENTS.md, Knowledge.md 작성
- Obsidian 기본 설정 (.obsidian/)
- 핵심 스킬 7개 구현
- Hooks 2개 구현
- 템플릿 5개 작성
- QA 워크플로우 구조 준비

### Phase 2 (팀 합류 후)
- Obsidian Git 플러그인으로 비개발자 push 자동화
- design-compare 스킬 (Figma vs 구현 자동 비교)
- onboard-member 스킬
- sprint-plan 스킬
- Notion/Confluence 자동 퍼블리시

### Phase 3 (성숙)
- GitHub Actions CI로 vault 일관성 자동 검증
- 주간 KPI 대시보드
- cross-repo drift detection (api/rn 코드 상태 자동 추적)
