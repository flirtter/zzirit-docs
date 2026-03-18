---
name: qa-dashboard
description: >
  전체 surface의 QA 현황을 집계하는 스킬.
  트리거: "QA 현황", "qa dashboard", "QA 대시보드"
---

## Instructions

### Step 1: 전체 surface 스캔

9개 surface 각각의 02. Project/{surface}/QA/ 디렉토리를 스캔.
각 .md 파일(QA.md 제외)의 frontmatter에서 status와 severity를 파싱.

### Step 2: 집계 테이블 출력

📊 QA Dashboard (날짜)

| surface | 🔴 critical | 🟡 major | 🟢 minor | 💄 cosmetic | ✅ fixed | 총 open |
테이블 형식으로 9개 surface + 합계 행 출력
