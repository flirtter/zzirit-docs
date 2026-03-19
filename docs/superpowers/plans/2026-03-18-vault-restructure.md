# ZZIRIT Vault Restructure Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transform zzirit-docs from a flat ops repo into an Obsidian vault with PARA structure and Claude Code harness.

**Architecture:** Reorganize existing assets into PARA folders (Projects by surface, Areas for persistent domains, Resources for scripts). Add Claude Code harness (CLAUDE.md, 7 skills, 2 hooks, settings.json). Add Obsidian config and templates for QA workflow.

**Tech Stack:** Obsidian (vault), Claude Code (skills/hooks in JS), Git LFS (design images), existing Python scripts preserved.

**Spec:** `docs/superpowers/specs/2026-03-18-vault-restructure-design.md`

---

### Task 1: Create PARA folder structure

**Files:**
- Create: `00. Inbox/.gitkeep`
- Create: `01. Journal/handovers/.gitkeep`
- Create: `01. Journal/workplans/.gitkeep`
- Create: `01. Journal/qa-reports/.gitkeep`
- Create: `02. Project/login/QA/.gitkeep`
- Create: `02. Project/login/attachments/.gitkeep`
- Create: `02. Project/onboarding/QA/.gitkeep`
- Create: `02. Project/onboarding/attachments/.gitkeep`
- Create: `02. Project/my/QA/.gitkeep`
- Create: `02. Project/my/attachments/.gitkeep`
- Create: `02. Project/likes/QA/.gitkeep`
- Create: `02. Project/likes/attachments/.gitkeep`
- Create: `02. Project/meeting/QA/.gitkeep`
- Create: `02. Project/meeting/attachments/.gitkeep`
- Create: `02. Project/chat/QA/.gitkeep`
- Create: `02. Project/chat/attachments/.gitkeep`
- Create: `02. Project/lightning/QA/.gitkeep`
- Create: `02. Project/lightning/attachments/.gitkeep`
- Create: `02. Project/billing/QA/.gitkeep`
- Create: `02. Project/billing/attachments/.gitkeep`
- Create: `02. Project/moderation/QA/.gitkeep`
- Create: `02. Project/moderation/attachments/.gitkeep`
- Create: `03. Area/Architecture/.gitkeep`
- Create: `03. Area/Decisions/.gitkeep`
- Create: `04. Resources/external/.gitkeep`
- Create: `05. Archive/.gitkeep`
- Create: `99. Templates/.gitkeep`

- [ ] **Step 1: Create all PARA directories**

```bash
cd /Users/user/zzirit-docs

# Top level PARA
mkdir -p "00. Inbox"
mkdir -p "01. Journal/handovers" "01. Journal/workplans" "01. Journal/qa-reports"

# Surface projects (9 surfaces)
for s in login onboarding my likes meeting chat lightning billing moderation; do
  mkdir -p "02. Project/$s/QA" "02. Project/$s/attachments"
done

# Areas
mkdir -p "03. Area/Architecture" "03. Area/Decisions"

# Resources, Archive, Templates
mkdir -p "04. Resources/external"
mkdir -p "05. Archive"
mkdir -p "99. Templates"
```

- [ ] **Step 2: Add .gitkeep files to empty dirs**

```bash
cd /Users/user/zzirit-docs
for d in "00. Inbox" "04. Resources/external" "05. Archive"; do
  touch "$d/.gitkeep"
done
```

- [ ] **Step 3: Commit**

```bash
cd /Users/user/zzirit-docs
git add "00. Inbox" "01. Journal" "02. Project" "03. Area" "04. Resources" "05. Archive" "99. Templates"
git commit -m "chore: create PARA folder structure for vault"
```

---

### Task 2: Move existing assets into PARA structure

**Files:**
- Move: `snapshots/HANDOVER_20260317.md` → `01. Journal/handovers/`
- Move: `HANDOVER_20260317.md` (root) → `01. Journal/handovers/`
- Move: `snapshots/WORKPLAN_20260318.md` → `01. Journal/workplans/`
- Move: `snapshots/QA_20260318.md` → `01. Journal/qa-reports/`
- Move: `references/surface-specs/{surface}.md` → `02. Project/{surface}/{surface}.md`
- Move: `references/figma-exports/` → `03. Area/Design/`
- Move: `references/manual-design/bundle-latest/` → `03. Area/Design/manual/`
- Move: `references/automation-scripts/` → `04. Resources/automation-scripts/`
- Move: `agents/` → `03. Area/Agents/`
- Move: `schemas/` → `03. Area/Database/`
- Move: `playbooks/` → `03. Area/Playbooks/`

- [ ] **Step 1: Move Journal items**

```bash
cd /Users/user/zzirit-docs

# Handovers (root + snapshots)
mv HANDOVER_20260317.md "01. Journal/handovers/"
cp snapshots/HANDOVER_20260317.md "01. Journal/handovers/HANDOVER_20260317_snapshot.md"

# Workplans
mv snapshots/WORKPLAN_20260318.md "01. Journal/workplans/" 2>/dev/null

# QA reports
mv snapshots/QA_20260318.md "01. Journal/qa-reports/" 2>/dev/null
```

- [ ] **Step 2: Move surface specs to Project folders**

Each surface spec becomes the surface MOC file.

```bash
cd /Users/user/zzirit-docs
for s in login onboarding my likes meeting chat lightning billing moderation; do
  if [ -f "references/surface-specs/$s.md" ]; then
    cp "references/surface-specs/$s.md" "02. Project/$s/$s.md"
  fi
done
# Also copy automation.md as a special surface
cp "references/surface-specs/automation.md" "02. Project/moderation/automation.md" 2>/dev/null
cp "references/surface-specs/README.md" "02. Project/README.md" 2>/dev/null
cp "references/surface-specs/manifest.json" "02. Project/manifest.json" 2>/dev/null
```

- [ ] **Step 3: Move Design assets**

```bash
cd /Users/user/zzirit-docs
mkdir -p "03. Area/Design"
# Figma exports
cp -r references/figma-exports/screens "03. Area/Design/screens"
cp -r references/figma-exports/flows "03. Area/Design/flows"
cp references/figma-exports/DESIGN-MAP.md "03. Area/Design/DESIGN-MAP.md"
cp references/figma-exports/screen-catalog.json "03. Area/Design/screen-catalog.json"
cp references/figma-exports/flow-catalog.json "03. Area/Design/flow-catalog.json"

# Manual design (only bundle-latest, skip downloads-design to deduplicate)
cp -r references/manual-design/bundle-latest "03. Area/Design/manual"
```

- [ ] **Step 4: Move Agents, Database, Playbooks, Resources**

```bash
cd /Users/user/zzirit-docs
cp -r agents "03. Area/Agents"
cp -r schemas "03. Area/Database"
cp -r playbooks "03. Area/Playbooks"
cp -r references/automation-scripts "04. Resources/automation-scripts"
```

- [ ] **Step 5: Commit asset migration**

```bash
cd /Users/user/zzirit-docs
git add "01. Journal" "02. Project" "03. Area" "04. Resources"
git commit -m "chore: migrate existing assets into PARA structure"
```

Note: Original files are preserved (copied, not moved) so existing scripts/references still work. A follow-up cleanup task can remove originals after verification.

---

### Task 3: Write Knowledge.md (top-level MOC)

**Files:**
- Create: `Knowledge.md`

- [ ] **Step 1: Write Knowledge.md**

```markdown
---
tags:
  - MOC
---
ZZIRIT 프로젝트의 최상위 MOC(Map of Content).
모든 탐색의 시작점이며, 하위 MOC를 통해 구체적인 노트로 탐색한다.

## 프로젝트 현황

- [[02. Project/02. Project]] — surface별 칸반 보드
- [[snapshots/current-state]] — 전체 상태 스냅샷
- [[snapshots/surface-status]] — surface 현황 요약

## Surface 프로젝트

- [[02. Project/login/login|login]] — 로그인
- [[02. Project/onboarding/onboarding|onboarding]] — 온보딩
- [[02. Project/my/my|my]] — MY 페이지
- [[02. Project/likes/likes|likes]] — 좋아요
- [[02. Project/meeting/meeting|meeting]] — 모임
- [[02. Project/chat/chat|chat]] — 채팅
- [[02. Project/lightning/lightning|lightning]] — 번개
- [[02. Project/billing/billing|billing]] — 결제
- [[02. Project/moderation/moderation|moderation]] — 관리

## 영구 영역

- [[03. Area/Design/DESIGN-MAP]] — 디자인 맵
- [[03. Area/Database/Database]] — DB 스키마
- [[03. Area/Agents/README]] — 에이전트 정의
- [[03. Area/Playbooks/github-projects]] — 운영 플레이북
- [[03. Area/Decisions/Decisions]] — 의사결정 기록

## 참고 자료

- [[04. Resources/automation-scripts]] — 자동화 스크립트

## 시스템 문서

- [[AGENTS]] — 에이전트 행동 규칙
- [[CLAUDE]] — Claude Code 진입점
```

- [ ] **Step 2: Commit**

```bash
cd /Users/user/zzirit-docs
git add Knowledge.md
git commit -m "docs: add Knowledge.md as top-level MOC"
```

---

### Task 4: Write CLAUDE.md and AGENTS.md

**Files:**
- Create: `CLAUDE.md`
- Create: `AGENTS.md`

- [ ] **Step 1: Write CLAUDE.md**

```markdown
## 이 vault는 ZZIRIT 프로젝트의 운영/맥락 허브다

코드 레포가 아니다. 실제 코드는 zzirit-rn, zzirit-api에 있다.
여기에는 상태, 결정, 스펙, QA, 디자인 자산, 세션 기록을 관리한다.

## 컨텍스트 로드 순서

1. Knowledge.md — 전체 탐색 진입점
2. snapshots/current-state.md — 프로젝트 현재 상태
3. 02. Project/02. Project.md — surface별 칸반 현황

## 핵심 규칙

- 새 노트 추가 시 반드시 상위 MOC에 링크
- surface spec 변경 시 snapshots/surface-status.md도 함께 갱신
- QA 노트의 이미지는 해당 surface의 attachments/에 저장
- 새 결정은 capture-decision 스킬로 ADR 생성
- 세션 종료 시 wrap-session 스킬로 handover 생성

## Surface 목록

login, onboarding, my, likes, meeting, chat, lightning, billing, moderation

## 에이전트 정의

멀티에이전트 실행 시 03. Area/Agents/ 참조:
- orchestrator.md — 전체 조율, 태스크 분배
- rn-dev.md — RN 앱 코드 개발
- api-dev.md — API 서버 개발
- ios-qa.md — iOS 빌드, 시각 QA
- design-review.md — Figma 디자인 비교
- qa-automation.md — E2E, 자동화 파이프라인
- planning.md — 스프린트 계획, 아키텍처

## Obsidian Vault 설정

이 레포 루트가 Obsidian vault root다.
attachments 폴더는 각 surface의 attachments/ 하위에 있다.
```

- [ ] **Step 2: Write AGENTS.md**

```markdown
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
```

- [ ] **Step 3: Commit**

```bash
cd /Users/user/zzirit-docs
git add CLAUDE.md AGENTS.md
git commit -m "docs: add CLAUDE.md and AGENTS.md for vault harness"
```

---

### Task 5: Write project MOC and QA folder notes

**Files:**
- Create: `02. Project/02. Project.md` (kanban board)
- Create: `02. Project/{surface}/QA/QA.md` for each surface (9 files)
- Create: `03. Area/Decisions/Decisions.md`
- Create: `03. Area/Database/Database.md`

- [ ] **Step 1: Write project kanban board**

`02. Project/02. Project.md`:

```markdown
---
kanban-plugin: board
---

## backlog

- [ ] [[billing/billing|billing]]
- [ ] [[moderation/moderation|moderation]]

## todo

- [ ] [[lightning/lightning|lightning]]

## doing

- [ ] [[login/login|login]]
- [ ] [[onboarding/onboarding|onboarding]]
- [ ] [[my/my|my]]
- [ ] [[likes/likes|likes]]
- [ ] [[meeting/meeting|meeting]]
- [ ] [[chat/chat|chat]]

## done



## hold



%% kanban:settings
{"kanban-plugin":"board","list-collapse":[false,false,false,false,false]}
%%
```

- [ ] **Step 2: Write QA folder notes for each surface**

For each surface, create `02. Project/{surface}/QA/QA.md`:

```markdown
---
tags:
  - QA
  - {surface}
up: "[[../{surface}]]"
---
{surface} surface의 QA 이슈 대시보드.

## Open Issues

(qa-dashboard 스킬이 자동 갱신)

## 이슈 등록 방법

1. 이 폴더에서 새 노트 생성
2. "QA Issue" 템플릿 선택
3. 스크린샷을 `../attachments/`에 드래그 앤 드롭
4. frontmatter 채우기 (surface, severity)
```

- [ ] **Step 3: Write area MOC stubs**

`03. Area/Decisions/Decisions.md`:

```markdown
---
tags:
  - MOC
---
팀 의사결정(ADR) 기록 모음.

## 결정 기록

(capture-decision 스킬로 추가)
```

`03. Area/Database/Database.md`:

```markdown
---
tags:
  - MOC
up: "[[Knowledge]]"
---
ZZIRIT 데이터베이스 스키마 모음.

## SQL Schemas

(schemas/ 에서 이동된 .sql 파일들)
```

- [ ] **Step 4: Commit**

```bash
cd /Users/user/zzirit-docs
git add "02. Project" "03. Area/Decisions" "03. Area/Database"
git commit -m "docs: add project kanban, QA folder notes, area MOCs"
```

---

### Task 6: Write templates

**Files:**
- Create: `99. Templates/QA Issue.md`
- Create: `99. Templates/Handover.md`
- Create: `99. Templates/Decision Record.md`
- Create: `99. Templates/Surface Project.md`
- Create: `99. Templates/QA Report.md`

- [ ] **Step 1: Write QA Issue template**

`99. Templates/QA Issue.md`:

```markdown
---
surface:
type: qa
reporter:
status: open
severity:
device:
created: <% tp.date.now("YYYY-MM-DD") %>
---

## 무엇이 문제인가



## 스크린샷

### 현재 구현 (문제 화면)


### 기대하는 모습 (디자인 시안)


## 재현 경로

1. 앱 실행
2.
3.

## 비고

```

- [ ] **Step 2: Write Handover template**

`99. Templates/Handover.md`:

```markdown
---
date: <% tp.date.now("YYYY-MM-DD") %>
type: handover
session_id:
---

## 이번 세션 요약



## 변경된 파일



## 미완료 TODO

- [ ]

## 다음 세션 추천 작업


```

- [ ] **Step 3: Write Decision Record template**

`99. Templates/Decision Record.md`:

```markdown
---
date: <% tp.date.now("YYYY-MM-DD") %>
status: Accepted
type: decision
surface:
---

## 맥락

(이 결정이 필요한 배경)

## 결정

(내린 결정)

## 대안

(검토한 대안과 장단점)

## 결과

(예상되는 긍정적/부정적 결과)
```

- [ ] **Step 4: Write Surface Project and QA Report templates**

`99. Templates/Surface Project.md`:

```markdown
---
tags:
  - project
  - MOC
surface:
status:
up: "[[02. Project/02. Project]]"
created: <% tp.date.now("YYYY-MM-DD") %>
---

## 세 줄 요약

-
-
-

## 현재 상태

- **QA Level:**
- **Automation:**
- **NEXT:**

## 인덱스

- [[QA/QA|QA Issues]]
```

`99. Templates/QA Report.md`:

```markdown
---
date: <% tp.date.now("YYYY-MM-DD") %>
type: qa-report
surface:
---

## QA 요약

| severity | count |
|----------|-------|
| critical | |
| major    | |
| minor    | |
| cosmetic | |

## 상세


```

- [ ] **Step 5: Commit**

```bash
cd /Users/user/zzirit-docs
git add "99. Templates"
git commit -m "docs: add vault templates (QA Issue, Handover, Decision, Surface, QA Report)"
```

---

### Task 7: Write Obsidian configuration

**Files:**
- Create: `.obsidian/app.json`
- Create: `.obsidian/appearance.json`
- Create: `.obsidian/community-plugins.json`
- Create: `.obsidian/core-plugins.json`
- Modify: `.gitignore`

- [ ] **Step 1: Write .obsidian/app.json**

```json
{
  "attachmentFolderPath": "./attachments",
  "newFileLocation": "folder",
  "newFileFolderPath": "00. Inbox",
  "showLineNumber": true,
  "strictLineBreaks": false,
  "useMarkdownLinks": false,
  "promptDelete": true
}
```

- [ ] **Step 2: Write .obsidian/appearance.json**

```json
{
  "baseFontSize": 16,
  "interfaceFontSize": 14
}
```

- [ ] **Step 3: Write .obsidian/core-plugins.json**

```json
[
  "file-explorer",
  "global-search",
  "switcher",
  "graph",
  "backlink",
  "outgoing-link",
  "tag-pane",
  "properties",
  "file-recovery",
  "bookmarks"
]
```

- [ ] **Step 4: Write .obsidian/community-plugins.json**

```json
[
  "obsidian-git",
  "templater-obsidian",
  "folder-notes",
  "obsidian-kanban",
  "dataview"
]
```

Note: These register plugin IDs. Users must install the actual plugins from Obsidian's community plugin browser on first open. A future `install-obsidian-plugins` skill can automate this.

- [ ] **Step 5: Update .gitignore**

Append to existing `.gitignore`:

```
# Obsidian
.obsidian/workspace.json
.obsidian/workspace-mobile.json
.obsidian/plugins/
.obsidian/themes/
.obsidian/hotkeys.json

# Keep tracked obsidian config
!.obsidian/app.json
!.obsidian/appearance.json
!.obsidian/community-plugins.json
!.obsidian/core-plugins.json
```

- [ ] **Step 6: Commit**

```bash
cd /Users/user/zzirit-docs
git add .obsidian .gitignore
git commit -m "chore: add Obsidian vault configuration"
```

---

### Task 8: Write Claude Code settings.json and hooks

**Files:**
- Create: `.claude/settings.json`
- Create: `.claude/hooks/session-briefing.js`
- Create: `.claude/hooks/check-moc-link.js`

- [ ] **Step 1: Write .claude/settings.json**

```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "node .claude/hooks/session-briefing.js"
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "node .claude/hooks/check-moc-link.js"
          }
        ]
      }
    ]
  },
  "permissions": {
    "allow": [
      "Bash(git:*)",
      "Bash(python3:*)",
      "Bash(node:*)",
      "Bash(ls:*)",
      "Bash(mkdir:*)",
      "Bash(cp:*)",
      "Bash(mv:*)"
    ]
  }
}
```

- [ ] **Step 2: Write session-briefing.js**

```js
#!/usr/bin/env node
// SessionStart hook: show last handover summary + open QA count
const fs = require('fs');
const path = require('path');

const root = process.cwd();

// Find most recent handover
const handoverDir = path.join(root, '01. Journal', 'handovers');
let lastHandover = '(no handover found)';
try {
  const files = fs.readdirSync(handoverDir)
    .filter(f => f.endsWith('.md'))
    .sort()
    .reverse();
  if (files.length > 0) {
    lastHandover = files[0].replace('.md', '');
  }
} catch (e) { /* dir may not exist yet */ }

// Count open QA issues across all surfaces
const surfaces = ['login','onboarding','my','likes','meeting','chat','lightning','billing','moderation'];
let openQA = 0;
for (const s of surfaces) {
  const qaDir = path.join(root, '02. Project', s, 'QA');
  try {
    const files = fs.readdirSync(qaDir).filter(f => f.endsWith('.md') && f !== 'QA.md');
    for (const f of files) {
      const content = fs.readFileSync(path.join(qaDir, f), 'utf8');
      if (content.includes('status: open')) openQA++;
    }
  } catch (e) { /* dir may not exist */ }
}

const msg = `Last handover: ${lastHandover} | Open QA: ${openQA}`;
process.stdout.write(msg);
```

- [ ] **Step 3: Write check-moc-link.js**

```js
#!/usr/bin/env node
// PostToolUse hook: warn if new .md files are not linked from a MOC
// This is a lightweight check - just outputs a reminder, does not block
const fs = require('fs');
const path = require('path');

// Hook receives tool info via env or stdin; for now just output a reminder
const msg = 'Reminder: If you created a new note, ensure it is linked from its parent MOC.';
process.stdout.write(msg);
```

- [ ] **Step 4: Commit**

```bash
cd /Users/user/zzirit-docs
git add .claude
git commit -m "feat: add Claude Code settings, hooks (session-briefing, moc-link-check)"
```

---

### Task 9: Write Claude Code skills (Phase 1 — 7 skills)

**Files:**
- Create: `.claude/skills/refresh/SKILL.md`
- Create: `.claude/skills/wrap-session/SKILL.md`
- Create: `.claude/skills/next-task/SKILL.md`
- Create: `.claude/skills/qa-review/SKILL.md`
- Create: `.claude/skills/qa-dashboard/SKILL.md`
- Create: `.claude/skills/capture-decision/SKILL.md`
- Create: `.claude/skills/update-surface/SKILL.md`

- [ ] **Step 1: Write refresh skill**

`.claude/skills/refresh/SKILL.md`:

```markdown
---
name: refresh
description: >
  프로젝트 상태 스냅샷을 갱신하는 스킬.
  트리거: "상태 갱신해줘", "refresh", "스냅샷 갱신"
---

## Instructions

### Step 1: 스냅샷 스크립트 실행

```bash
cd /Users/user/zzirit-docs
python3 scripts/refresh_snapshot.py
```

스크립트가 없거나 실패하면 사용자에게 보고.

### Step 2: 변경 요약

`snapshots/current-state.md`와 `snapshots/surface-status.md`를 읽고
이전 상태와 비교하여 변경사항을 요약한다.

### Step 3: 커밋

```bash
git add snapshots/
git commit -m "chore: refresh snapshots $(date +%Y-%m-%d)"
```

### Step 4: 보고

```
✅ 스냅샷 갱신 완료
📁 변경 파일: N개
📋 주요 변경: [요약]
```
```

- [ ] **Step 2: Write wrap-session skill**

`.claude/skills/wrap-session/SKILL.md`:

```markdown
---
name: wrap-session
description: >
  세션 종료 시 handover 문서를 자동 생성하는 스킬.
  트리거: "세션 마무리해줘", "wrap session", "핸드오버 생성"
---

## Instructions

### Step 1: 변경 분석

`git diff --stat HEAD~5` 또는 이번 세션에서 변경된 파일 목록을 수집한다.

### Step 2: Handover 생성

`01. Journal/handovers/HANDOVER_YYYYMMDD.md` 파일을 생성한다.
`99. Templates/Handover.md` 구조를 따른다.

내용:
- 이번 세션 요약 (변경 파일 기반)
- 미완료 TODO (QA open 이슈, backlog 기반)
- 다음 세션 추천 작업

### Step 3: 커밋

```bash
git add "01. Journal/handovers/"
git commit -m "docs: session handover $(date +%Y-%m-%d)"
```

### Step 4: 보고

```
✅ 핸드오버 생성 완료
📁 01. Journal/handovers/HANDOVER_YYYYMMDD.md
📋 변경 파일: N개
📌 미완료: M건
```
```

- [ ] **Step 3: Write next-task skill**

`.claude/skills/next-task/SKILL.md`:

```markdown
---
name: next-task
description: >
  다음 작업을 추천하는 스킬. backlog, surface status, 블로커를 분석.
  트리거: "다음 뭐해?", "next task", "다음 작업 추천"
---

## Instructions

### Step 1: 데이터 수집

1. `snapshots/issue-backlog.md` 읽기
2. `snapshots/surface-status.md` 읽기
3. `02. Project/*/QA/` 에서 `status: open` + `severity: critical` QA 노트 스캔
4. `snapshots/current-state.md`에서 블로커 확인

### Step 2: 우선순위 분석

우선순위 기준:
1. 🔴 Critical QA 이슈 (severity: critical)
2. 🟡 블로커가 있는 surface
3. 🟢 surface-status에서 next_step이 있는 항목
4. ⚪ backlog의 미해결 이슈

### Step 3: 추천 출력

```
📋 다음 작업 추천

1. 🔴 [surface] — [이슈 요약] (critical QA)
2. 🟡 [surface] — [블로커 설명]
3. 🟢 [surface] — [next_step]

💡 추천: [가장 높은 우선순위 작업 설명]
```
```

- [ ] **Step 4: Write qa-review skill**

`.claude/skills/qa-review/SKILL.md`:

```markdown
---
name: qa-review
description: >
  특정 surface의 open QA 이슈를 리뷰하고 이미지 비교 분석하는 스킬.
  트리거: "QA 리뷰해줘 {surface}", "qa review {surface}"
---

## Instructions

### Step 1: QA 노트 수집

`02. Project/{surface}/QA/` 에서 `status: open` 인 .md 파일을 모두 읽는다.
`QA.md` (폴더 노트)는 제외.

### Step 2: 이미지 분석

각 QA 노트에서:
1. `## 스크린샷` 섹션의 이미지 wikilink를 파싱
2. `![[파일명.png]]` → `02. Project/{surface}/attachments/파일명.png` 경로로 변환
3. Read tool로 이미지를 읽어 멀티모달 분석
4. "현재 구현" vs "기대하는 모습" 이미지를 비교
5. `03. Area/Design/screens/` 의 원본 Figma 시안과도 대조

### Step 3: 리포트 생성

severity별로 그룹핑하여 출력:

```
📋 QA Review: {surface} (YYYY-MM-DD)

🔴 Critical (N건)
  - [이슈 제목] — [분석 결과]
    현재 vs 디자인: [구체적 차이]

🟡 Major (N건)
  - ...

🟢 Minor (N건)
  - ...

요약: N건 open / M건 fixed
```
```

- [ ] **Step 5: Write qa-dashboard skill**

`.claude/skills/qa-dashboard/SKILL.md`:

```markdown
---
name: qa-dashboard
description: >
  전체 surface의 QA 현황을 집계하는 스킬.
  트리거: "QA 현황", "qa dashboard", "QA 대시보드"
---

## Instructions

### Step 1: 전체 surface 스캔

9개 surface 각각의 `02. Project/{surface}/QA/` 디렉토리를 스캔.
각 .md 파일(QA.md 제외)의 frontmatter에서 `status`와 `severity`를 파싱.

### Step 2: 집계 테이블 출력

```
📊 QA Dashboard (YYYY-MM-DD)

| surface     | 🔴 critical | 🟡 major | 🟢 minor | 💄 cosmetic | ✅ fixed | 총 open |
|-------------|:-----------:|:--------:|:--------:|:-----------:|:--------:|:-------:|
| login       |             |          |          |             |          |         |
| onboarding  |             |          |          |             |          |         |
| my          |             |          |          |             |          |         |
| likes       |             |          |          |             |          |         |
| meeting     |             |          |          |             |          |         |
| chat        |             |          |          |             |          |         |
| lightning   |             |          |          |             |          |         |
| billing     |             |          |          |             |          |         |
| moderation  |             |          |          |             |          |         |
| **합계**    |             |          |          |             |          |         |
```
```

- [ ] **Step 6: Write capture-decision skill**

`.claude/skills/capture-decision/SKILL.md`:

```markdown
---
name: capture-decision
description: >
  팀 의사결정을 ADR 형식으로 기록하는 스킬.
  트리거: "결정 기록해줘", "ADR 생성", "capture decision"
---

## Instructions

### Step 1: 결정 정보 수집

입력이 없으면 다음을 순서대로 요청:
1. 결정 내용 (한 문장)
2. 배경 (왜 이 결정이 필요했는가)
3. 검토한 대안 (1개 이상)

### Step 2: ADR 생성

`99. Templates/Decision Record.md` 형식으로 작성.
저장 경로: `03. Area/Decisions/YYYY-MM-DD [결정 제목].md`

### Step 3: MOC 업데이트

`03. Area/Decisions/Decisions.md`에 링크 추가:

```markdown
- [[YYYY-MM-DD 결정 제목]]
```

### Step 4: 커밋

```bash
git add "03. Area/Decisions/"
git commit -m "docs: ADR - [결정 제목]"
```
```

- [ ] **Step 7: Write update-surface skill**

`.claude/skills/update-surface/SKILL.md`:

```markdown
---
name: update-surface
description: >
  surface의 상태를 갱신하는 스킬. spec, surface-status, 칸반을 동시 업데이트.
  트리거: "{surface} 상태 업데이트", "update surface {surface}"
---

## Instructions

### Step 1: 변경 내용 파악

사용자에게 변경할 내용을 확인:
- qa_level 변경?
- automation_status 변경?
- current_state 변경?
- next_step 변경?

### Step 2: Surface MOC 업데이트

`02. Project/{surface}/{surface}.md`의 frontmatter 또는 본문 갱신.

### Step 3: Surface Status 업데이트

`snapshots/surface-status.md` 테이블에서 해당 surface 행 갱신.

### Step 4: 칸반 보드 업데이트

상태 변경이 칸반 이동을 수반하면 `02. Project/02. Project.md` 갱신.
(예: implemented → done 이면 doing에서 done으로 이동)

### Step 5: 커밋

```bash
git add "02. Project/" snapshots/surface-status.md
git commit -m "docs: update {surface} status"
```

### Step 6: 보고

```
✅ {surface} 상태 업데이트 완료
📋 변경: [변경 요약]
```
```

- [ ] **Step 8: Commit all skills**

```bash
cd /Users/user/zzirit-docs
git add .claude/skills
git commit -m "feat: add 7 Claude Code skills (refresh, wrap-session, next-task, qa-review, qa-dashboard, capture-decision, update-surface)"
```

---

### Task 10: Setup Git LFS for images and update .gitattributes

**Files:**
- Create: `.gitattributes`

- [ ] **Step 1: Initialize Git LFS**

```bash
cd /Users/user/zzirit-docs
git lfs install
```

- [ ] **Step 2: Create .gitattributes**

```
# Track image files with Git LFS
03. Area/Design/screens/**/*.png filter=lfs diff=lfs merge=lfs -text
03. Area/Design/flows/**/*.png filter=lfs diff=lfs merge=lfs -text
03. Area/Design/manual/**/*.png filter=lfs diff=lfs merge=lfs -text
02. Project/*/attachments/*.png filter=lfs diff=lfs merge=lfs -text
02. Project/*/attachments/*.jpg filter=lfs diff=lfs merge=lfs -text
```

- [ ] **Step 3: Commit**

```bash
cd /Users/user/zzirit-docs
git add .gitattributes
git commit -m "chore: setup Git LFS for design and QA images"
```

Note: Existing images in `references/` are not migrated to LFS in this task. That is a follow-up cleanup.

---

### Task 11: Final verification and update README

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Verify folder structure**

```bash
cd /Users/user/zzirit-docs
echo "=== PARA Structure ==="
ls -d "00. Inbox" "01. Journal" "02. Project" "03. Area" "04. Resources" "05. Archive" "99. Templates"
echo "=== Surface Projects ==="
ls "02. Project/"
echo "=== Skills ==="
ls .claude/skills/
echo "=== Hooks ==="
ls .claude/hooks/
echo "=== Obsidian ==="
ls .obsidian/
echo "=== Templates ==="
ls "99. Templates/"
```

Expected: all directories and files exist.

- [ ] **Step 2: Update README.md**

Add a section at the top of README.md explaining the new vault structure:

```markdown
# ZZIRIT Memory Hub

ZZIRIT 프로젝트의 운영/맥락 허브. Obsidian vault + Claude Code 하네스.

## Quick Start

### Obsidian으로 열기
1. Obsidian → "Open folder as vault" → 이 폴더 선택
2. Community plugins 활성화
3. 권장 플러그인 설치: Obsidian Git, Templater, Folder Notes, Kanban, Dataview

### Claude Code로 사용
이 폴더에서 Claude Code 실행 — CLAUDE.md가 자동 로드됨.

## 구조

```
00. Inbox/          ← 미분류 자료
01. Journal/        ← 세션 기록 (handover, workplan, QA report)
02. Project/        ← surface별 프로젝트 (login, onboarding, my, ...)
03. Area/           ← 영구 영역 (Design, Database, Agents, Decisions, Playbooks)
04. Resources/      ← 참고 자료 (automation scripts)
05. Archive/        ← 완료 프로젝트
99. Templates/      ← 노트 템플릿
.claude/skills/     ← Claude Code 스킬 7개
```

탐색 시작점: [Knowledge.md](Knowledge.md)
```

Preserve all existing README content below the new section.

- [ ] **Step 3: Commit**

```bash
cd /Users/user/zzirit-docs
git add README.md
git commit -m "docs: update README with vault structure guide"
```
