---
name: zzirit-refresh
description: >
  프로젝트 상태 스냅샷을 갱신하는 스킬.
  트리거: "상태 갱신해줘", "refresh", "스냅샷 갱신"
---

## Instructions

### Step 1: 스냅샷 스크립트 실행

scripts/refresh_snapshot.py를 실행한다.
스크립트가 없거나 실패하면 사용자에게 보고.

### Step 2: 변경 요약

snapshots/current-state.md와 snapshots/surface-status.md를 읽고
이전 상태와 비교하여 변경사항을 요약한다.

### Step 3: 커밋

변경된 snapshots/ 파일을 커밋한다.

### Step 4: 보고

✅ 스냅샷 갱신 완료 / 변경 파일 수 / 주요 변경 요약
