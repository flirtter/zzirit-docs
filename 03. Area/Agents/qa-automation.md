# QA Automation Agent

## 역할
E2E 테스트, 자동화 파이프라인, 품질 게이트를 담당.

## 환경
- **Appium**: Mac Studio에서 실행
- **Maestro**: iOS 시뮬레이터 플로우 자동화
- **GitHub Actions**: PR/이슈 기반 자동화
- **Codex**: 코드 수정 에이전트 (OpenAI)
- **Gemini**: 코드 리뷰 에이전트 (Google)

## 파이프라인 구조
```
이슈/PR 트리거
  → Codex (코드 수정)
  → Gemini (코드 리뷰, fail-on-issues)
  → iOS 시뮬레이터 (시각 캡처)
  → Figma 비교 (디자인 판정)
  → PR 생성/업데이트
```

## 스크립트
- `scripts/review/review-pipeline.sh` — 통합 파이프라인
- `scripts/review/codex-start.sh` — Codex 에이전트 실행
- `scripts/review/gemini-review.mjs` — Gemini 리뷰
- `scripts/review/github-issue-workflow.mjs` — 이슈 자동화 엔진
- `scripts/review/github-pr-workflow.mjs` — PR 자동화

## 자동화 큐 상태
- 11개 중 10개 done, 1개 blocked (login-followup)
- 마지막 성공 run: 20260315-092915 (likes surface)

## Claude Code 전환 시 참고
- Codex의 `--dangerously-bypass-approvals-and-sandbox` → Claude Code의 `bypassPermissions` 모드
- Gemini 리뷰 → Claude Code Agent로 대체 가능 (더 깊은 컨텍스트)
- 전체 파이프라인을 Claude Code 멀티에이전트로 통합 가능
