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
