# ZZIRIT Agent Definitions

## 구조

agents/ 는 이중 구조로 구성됨:

- **상위 .md 파일** (orchestrator.md 등): Claude Code Agent tool로 멀티에이전트 실행 시 빠르게 로드하는 요약 컨텍스트
- **서브디렉토리** (api/, ios/ 등): 에이전트별 상세 지식 (IDENTITY, KNOWLEDGE, SCRATCHPAD, SOP)

## 에이전트 목록

| Agent | 요약 | 상세 | 역할 |
|-------|------|------|------|
| orchestrator | orchestrator.md | orchestrator/ | 전체 조율, 태스크 분배 |
| rn-dev | rn-dev.md | ios/ | RN 앱 코드 개발 |
| api-dev | api-dev.md | api/ | API 서버 개발 |
| ios-qa | ios-qa.md | ios/ | iOS 빌드, 시각 QA |
| design-review | design-review.md | design/ | Figma 디자인 비교 |
| qa-automation | qa-automation.md | qa/ | E2E, 자동화 파이프라인 |
| planning | planning.md | planning/ | 스프린트 계획, 아키텍처 |

## 실행 방법

### Claude Code 멀티에이전트 (권장)

오케스트레이터로 팀모드 시작:
> agents/orchestrator.md를 읽고 팀모드로 진행해줘

특정 에이전트만 실행:
> agents/rn-dev.md와 agents/ios/KNOWLEDGE.md를 읽고 이 작업을 해줘

### Codex 자동화 (기존)
cron → tmux → codex-batch-loop.sh → codex-next-batch.sh
(현재 크레딧 소진으로 3/19까지 중단)

### Gemini 리뷰 (기존)
GitHub Actions: gemini-pr-review.yml, gemini-sanity-check.yml
