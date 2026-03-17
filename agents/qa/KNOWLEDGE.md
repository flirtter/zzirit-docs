# QA Agent Knowledge Base

## 자동화 파이프라인 구조

이슈/PR 트리거 → Codex(코드수정) → Gemini(리뷰) → iOS(캡처) → Figma(판정)

## 알려진 문제점 (2026-03-18)

### 1. Codex 크레딧 소진
- 에러: You have hit your usage limit
- 영향: 3/19 01:43 AM까지 배치 실패 반복
- 대응: 크레딧 충전 또는 Claude Code 전환

### 2. codex-next-batch.sh:429 Parse Error
- 원인: Python heredoc이 zsh에서 파싱 에러
- 수정: heredoc를 별도 .py 파일로 분리 필요

### 3. lsof PATH 문제
- 원인: cron 환경에서 /usr/sbin이 PATH에 없음
- 위치: scripts/review/open-ios-real-env.sh:67
- 수정: 절대경로 /usr/sbin/lsof 사용

### 4. 포커스 세션 만료
- likes 세션이 3/17 13:42 만료 but pinned=true
- 같은 섹션만 반복 중

## 자동화 큐 현황
- 11개 중 10개 done, 1개 blocked (login-followup)
- 마지막 성공: 20260315-092915 (likes)
- 누적 배치: 253개, 성공률 99.2%
- 자동 커밋: 27회
