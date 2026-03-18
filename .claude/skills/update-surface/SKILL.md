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

02. Project/{surface}/{surface}.md의 frontmatter 또는 본문 갱신.

### Step 3: Surface Status 업데이트

snapshots/surface-status.md 테이블에서 해당 surface 행 갱신.

### Step 4: 칸반 보드 업데이트

상태 변경이 칸반 이동을 수반하면 02. Project/02. Project.md 갱신.

### Step 5: 커밋 + 보고

✅ {surface} 상태 업데이트 완료 / 변경 요약
