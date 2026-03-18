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

99. Templates/Decision Record.md 형식으로 작성.
저장 경로: 03. Area/Decisions/YYYY-MM-DD [결정 제목].md

### Step 3: MOC 업데이트

03. Area/Decisions/Decisions.md에 링크 추가.

### Step 4: 커밋

03. Area/Decisions/ 파일을 커밋한다.
