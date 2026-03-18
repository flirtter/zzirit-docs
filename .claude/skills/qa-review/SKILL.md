---
name: qa-review
description: >
  특정 surface의 open QA 이슈를 리뷰하고 이미지 비교 분석하는 스킬.
  트리거: "QA 리뷰해줘 {surface}", "qa review {surface}"
---

## Instructions

### Step 1: QA 노트 수집

02. Project/{surface}/QA/ 에서 status: open 인 .md 파일을 모두 읽는다.
QA.md (폴더 노트)는 제외.

### Step 2: 이미지 분석

각 QA 노트에서:
1. 스크린샷 섹션의 이미지 wikilink를 파싱
2. ![[파일명.png]] → 02. Project/{surface}/attachments/파일명.png 경로로 변환
3. Read tool로 이미지를 읽어 멀티모달 분석
4. "현재 구현" vs "기대하는 모습" 이미지를 비교
5. 03. Area/Design/screens/ 의 원본 Figma 시안과도 대조

### Step 3: 리포트 생성

severity별로 그룹핑하여 출력:
📋 QA Review: {surface} / Critical N건 / Major N건 / Minor N건 / 요약
