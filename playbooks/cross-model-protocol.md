# Cross-Model Collaboration Protocol

## 참여 모델
| 모델 | 역할 | 실행 환경 |
|------|------|----------|
| **Claude Code** | 오케스트레이터, 코드 개발, 아키텍처 | 맥북/맥 스튜디오 (SSH) |
| **OpenAI Codex** | 코드 수정 에이전트, 자동화 루프 | 맥북 (`~/.codex/`) |
| **Gemini** | PR 리뷰, 이슈 트리아지, Sanity Check | GitHub Actions |

## 핸드오버 프로토콜
1. 작업 완료 시 `snapshots/HANDOVER_YYYYMMDD.md` 작성
2. `snapshots/current-state.md` 갱신
3. 미해결 사항은 `issue-backlog.md`에 추가
4. 다음 모델은 HANDOVER → current-state → agents/ 순으로 읽고 시작

## 메모리 공유 규칙
- **snapshots/**: 현재 상태 (모든 모델이 읽기/쓰기)
- **agents/**: 에이전트 정의 (주로 Claude Code가 관리)
- **references/**: 불변 참조 (spec, 디자인, 스크립트)
- **playbooks/**: 운영 규칙 (사람이 관리, 모델이 참조)

## 충돌 방지
- 같은 파일을 동시에 수정하지 않음
- surface 단위로 작업 범위 분리
- 커밋 메시지에 모델명 태그: `[claude]`, `[codex]`, `[gemini]`

## 에스컬레이션
- 모델이 해결 불가 시 → `issue-backlog.md`에 blocked로 기록
- 사람 개입 필요 시 → 이슈 설명에 `NEEDS_HUMAN` 태그
