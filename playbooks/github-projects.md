# GitHub Projects Playbook

`zzirit-memory-hub`의 GitHub Projects는 작업 현황판이다. 구현 저장소가 아니라 운영 저장소인 만큼, 이슈는 맥락과 작업 단위를 담고 Projects는 현재 상태를 한눈에 보여주는 역할을 맡는다.

## 목적

- 현재 작업 큐를 사람과 자동화가 같은 화면에서 추적
- surface별 진행 상태, QA 수준, 디자인 게이트 상태를 공통 필드로 관리
- 자동화가 남긴 결과를 이슈/프로젝트 상태와 연결
- 다음 작업 전환 기준을 GitHub에서도 확인 가능하게 유지

## 권장 프로젝트

- 이름: `ZZIRIT Delivery`
- 소스: `zzirit-memory-hub` 이슈
- owner: `ahg0223`
- 현재 생성된 프로젝트:
  - `https://github.com/users/ahg0223/projects/1`

## 권장 필드

- `Status`
  - `Todo`
  - `In Progress`
  - `QA`
  - `Blocked`
  - `Done`
- `Surface`
  - `login`
  - `onboarding`
  - `my`
  - `likes`
  - `meeting`
  - `chat`
  - `lightning`
  - `automation`
- `Type`
  - `design`
  - `qa`
  - `automation`
  - `refactor`
  - `infra`
- `QA Level`
  - `manual`
  - `appium`
  - `host_qa`
  - `strict`
- `Design Gate`
  - `missing`
  - `partial`
  - `pass`
- `Automation`
  - `none`
  - `partial`
  - `full`
- `Priority`
  - `P0`
  - `P1`
  - `P2`
  - `P3`
- `Spec`
  - surface spec 파일 경로나 링크
- `Artifacts`
  - 최신 QA 산출물 경로나 링크
- `Blocker`
  - 외부 의존성/권한/실기기 이슈

## 권장 뷰

- `Now`
  - `Status != Done`
  - 우선순위와 surface를 같이 본다.
- `QA Queue`
  - `Status == QA`
- `Blocked`
  - `Status == Blocked`
- `By Surface`
  - `Board`, column by `Surface`
- `Roadmap`
  - `Date` 필드를 추가할 수 있으면 사용
- `Done This Week`
  - 최근 완료 항목 검토용

## 현재 운영 규칙

- issue 제목은 한국어, stable key는 대괄호 slug로 유지
  - 예: `[meeting-followup] 미팅 후속 정리`
- 자동화가 읽는 기준은
  - issue body
  - labels
  - `snapshots/current-state.json`
  - `references/surface-specs/*`
- 구현/QA는 `zzirit-v2`와 Mac Studio에서 수행
- 결과 요약은 `zzirit-memory-hub`에 남김

## 자동화 연결 방향

현재 이미 연결된 것:

- 이슈 템플릿
- surface spec
- QA 스냅샷
- automation run note

추가 연결 대상:

- GitHub Project item 자동 생성
- field 업데이트
- 완료 시 issue close + project status `Done`
- blocked 반복 시 project status `Blocked`

## 현재 상태

- 로컬 `gh` 인증에는 현재 다음 scope가 반영되어 있다.
  - `project`
  - `read:org`
  - `read:discussion`
- 프로젝트 `ZZIRIT Delivery` 생성 완료
- 현재 open issue 14개가 프로젝트에 반영됨
- field 20개 구성 완료

## 실행 순서

1. `scripts/export_project_seed.py` 로 현재 이슈를 seed 파일로 생성
2. `scripts/sync_github_project.py` 로 project item/field 동기화
3. 필요 시 `scripts/bootstrap_github_project.py` 로 scope/부트스트랩 상태 확인
4. 이후 automation 결과를 이슈와 프로젝트에 계속 반영
