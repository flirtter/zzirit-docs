# ZZIRIT Memory Hub

ZZIRIT 작업의 장기 기억 저장소다.

목적:
- `zzirit-v2`, `zzirit-proxy`의 현재 상태와 커밋 맥락을 보존
- surface별 사양, QA 상태, 자동화 상태를 GitHub 이슈/문서 기반으로 관리
- 이후 유지보수/QA/리팩토링 시 이 레포를 기준 문맥으로 사용

현재 원격:
- `https://github.com/ahg0223/zzirit-memory-hub`

구성:
- `snapshots/`: 현재 로컬/원격 상태에서 생성한 스냅샷
- `.github/ISSUE_TEMPLATE/`: QA, 디자인 갭, 자동화 플래키, 리팩토링 추적용 이슈 템플릿
- `scripts/refresh_snapshot.py`: 현재 작업 트리와 Mac Studio 원격 상태를 다시 수집해 스냅샷을 갱신
- `PUBLISHING.md`: GitHub 원격 레포 생성/푸시 절차

기본 운영 원칙:
- 이 레포는 코드 레포가 아니라 운영/맥락 레포다.
- 실제 구현은 `zzirit-v2`, `zzirit-proxy`에서 하고, 여기엔 요약/상태/결정/이슈를 남긴다.
- surface별 세부 상태는 `snapshots/surface-status.md` 와 `snapshots/current-state.json`을 우선 참고한다.
- 자동화의 현재 큐/상태는 `snapshots/automation-state.md` 와 `snapshots/current-state.json`을 우선 참고한다.

현재 GitHub 운영:
- 레포 이름: `zzirit-memory-hub`
- 공개 여부: `private`
- 기본 라벨:
  - `surface:login`
  - `surface:onboarding`
  - `surface:my`
  - `surface:likes`
  - `surface:meeting`
  - `surface:chat`
  - `surface:automation`
  - `qa`
  - `design-gap`
  - `flake`
  - `refactor`
  - `automation`

현재 생성된 초기 이슈:
- `#1` `my-followup`
- `#2` `onboarding-followup`
- `#3` `login-followup`
- `#4` `meeting-followup`
- `#5` `likes-followup`

갱신:
```bash
cd /Users/user/zzirit-memory-hub
python3 scripts/refresh_snapshot.py
```
