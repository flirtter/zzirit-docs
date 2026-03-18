# ZZIRIT Agent Definitions

Claude Code 멀티에이전트 팀모드에서 사용하는 에이전트 역할 정의.
각 파일은 에이전트의 역할, 도구, 컨텍스트, 프로토콜을 정의한다.

## 에이전트 목록

| Agent | 파일 | 역할 |
|-------|------|------|
| orchestrator | orchestrator.md | 전체 작업 조율, 태스크 분배, 상태 추적 |
| rn-dev | rn-dev.md | React Native 앱 코드 개발 (zzirit-rn) |
| api-dev | api-dev.md | API 서버 개발 (zzirit-proxy, zzirit-v2/apps/api) |
| ios-qa | ios-qa.md | iOS 빌드, 시뮬레이터 QA, 시각 검증 |
| design-review | design-review.md | Figma 디자인 비교, UI 정합성 검증 |
| qa-automation | qa-automation.md | E2E 테스트, Appium, 자동화 파이프라인 |
| planning | planning.md | 스프린트 계획, 이슈 분석, 아키텍처 설계 |

## 실행 방법

Claude Code에서 팀 모드로 실행:
```
# 단일 에이전트 실행
이 에이전트 정의를 읽고 해당 역할로 작업해줘: agents/rn-dev.md

# 멀티에이전트 병렬 실행
orchestrator.md를 읽고 팀모드로 다음 작업을 진행해줘: [작업 설명]
```

## Codex/Gemini 연동

- **Codex**: `scripts/review/codex-start.sh`로 코드 수정 에이전트 실행
- **Gemini**: GitHub Actions PR Review + `scripts/review/gemini-review.mjs`
- **Claude Code**: 이 agents/ 정의로 멀티에이전트 오케스트레이션
