# QA Workflow Decision

## 배경

QA 이슈 관리를 어디서 할 것인가에 대한 의사결정.

## Option A: GitHub Issues

- QA 이슈를 GitHub Issue로 등록
- `gemini-issue-triage.yml`이 자동 라벨링
- 개발자가 이슈 단위로 작업
- 장점: 추적성, 할당, 알림 기본 제공
- 단점: 상세 분석/맥락이 부족할 수 있음

## Option B: Vault MD

- QA 이슈를 surface/QA/ 하위에 md로 관리
- 스킬로 자동 집계
- 장점: 상세 맥락, 스크린샷, 관련 노트 링크 용이
- 단점: 추적/할당/알림 기능 없음

## Recommendation: 하이브리드

**GitHub Issue + Vault MD 병행**

1. **GitHub Issue로 등록** — tracking/assignment 용도
   - Issue template에 surface 라벨 자동 부여
   - 이미 `.github/ISSUE_TEMPLATE/`에 `qa-flake.md` 템플릿 있음
   - `gemini-issue-triage.yml`이 라벨/우선순위 자동 분류

2. **Vault MD에 상세 분석** — context 용도
   - 재현 순서, 스크린샷, 관련 커밋, 근본 원인 분석
   - surface별 QA/ 하위에 저장
   - GitHub Issue 번호를 md 프론트매터에 기록하여 양방향 링크

3. **워크플로우**
   - QA 발견 → GitHub Issue 생성 (template 사용)
   - 상세 분석 필요 시 vault md 작성, issue 번호 연결
   - 수정 완료 → issue close + vault md에 해결 기록
