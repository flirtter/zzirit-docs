---
name: zzirit-wrap-session
description: >
  세션 종료 시 handover 문서를 자동 생성하는 스킬.
  트리거: "세션 마무리해줘", "wrap session", "핸드오버 생성"
---

## Instructions

### Step 1: 변경 분석

git diff --stat HEAD~5 또는 이번 세션에서 변경된 파일 목록을 수집한다.

### Step 2: Handover 생성

01. Journal/handovers/HANDOVER_YYYYMMDD.md 파일을 생성한다.
99. Templates/Handover.md 구조를 따른다.

내용:
- 이번 세션 요약 (변경 파일 기반)
- 미완료 TODO (QA open 이슈, backlog 기반)
- 다음 세션 추천 작업

### Step 3: 커밋

01. Journal/handovers/ 파일을 커밋한다.

### Step 4: 보고

✅ 핸드오버 생성 완료 / 파일 경로 / 변경 파일 수 / 미완료 건수
