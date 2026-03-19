---
name: zzirit-next-task
description: >
  다음 작업을 추천하는 스킬. backlog, surface status, 블로커를 분석.
  트리거: "다음 뭐해?", "next task", "다음 작업 추천"
---

## Instructions

### Step 1: 데이터 수집

1. snapshots/issue-backlog.md 읽기
2. snapshots/surface-status.md 읽기
3. 02. Project/*/QA/ 에서 status: open + severity: critical QA 노트 스캔
4. snapshots/current-state.md에서 블로커 확인

### Step 2: 우선순위 분석

1. 🔴 Critical QA 이슈
2. 🟡 블로커가 있는 surface
3. 🟢 next_step이 있는 항목
4. ⚪ backlog 미해결 이슈

### Step 3: 추천 출력

📋 다음 작업 추천 (우선순위별 1-3건) + 💡 추천 요약
