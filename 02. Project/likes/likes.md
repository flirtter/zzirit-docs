---
surface: likes
spec_status: draft
qa_level: host_qa
automation_status: high
---

# Likes Surface Contract

## Source Order

1. Manual design bundle:
   - `/Users/user/zzirit-v2/artifacts/manual-design-references/latest/MY`
2. Latest likes Appium review:
   - `/Users/user/zzirit-v2/artifacts/appium-likes/20260314-015105/summary.md`
3. Latest likes release capture:
   - `/Users/user/zzirit-v2/artifacts/manual-review/likes-release-*/summary.md`
4. Current implementation target:
   - `/Users/user/zzirit-v2/apps/mobile/app/likes.tsx`

## Canonical Tabs

- `received`
- `sent`
- `zzirit`

## Non-Negotiable Structure

- Received likes start in a locked preview state.
- Unlock confirmation must be in-app and design-shaped, not a native alert.
- After unlock, preview modal must show profile detail before navigation.
- Sent and ZZIRIT tabs must remain reachable from the same top tab bar.

## Data Rules

- Review seed must provide enough received/sent/match data to render all three tabs.
- Locked/unlocked states must be deterministic in QA.
- The design should never depend on empty placeholder grids only.

## 2026-03-20 변경사항

- ✅ 블러/볼트 결제 시스템 추가: 받은 좋아요 카드에 블러 처리, 볼트 결제로 잠금 해제
- ✅ 데모 데이터 폴백: 서버 데이터 없을 시 데모 프로필로 UI 렌더링
- ✅ AsyncStorage 구매 상태 영속화: 결제 완료 상태를 앱 재시작 후에도 유지

## QA Snapshot

- Latest dedicated Appium review is success:
  `/Users/user/zzirit-v2/artifacts/appium-likes/20260314-015105/summary.md`
- Core artifacts:
  - `01-received-locked.png`
  - `02-unlock-dialog.png`
  - `03-received-unlocked.png`
  - `04-preview-modal.png`
  - `05-sent.png`
  - `06-zzirit.png`

## Known Gaps

- 실 서버 like API 연동 필요 — 현재 클라이언트 사이드 데모 데이터로 동작
- Pre-blurred 이미지 최적화 필요 — 현재 클라이언트에서 실시간 블러 처리 (성능 이슈 가능)
- Release capture는 아직 상위 3탭만 커버
- Unlock dialog, preview modal은 Appium review 기반 (release-only capture 아님)

## QA
- [[QA/QA|QA 현황]]

## Done Criteria

- Received, sent, and ZZIRIT tabs all render with real seeded data.
- Unlock and preview modal are stable in Appium.
- Likes host QA must emit both Appium and release-capture evidence.
- ✅ 블러/볼트 결제 시스템 추가 (2026-03-20)
- ✅ 데모 데이터 폴백 (2026-03-20)
- ✅ AsyncStorage 구매 상태 영속화 (2026-03-20)
- [ ] 실 서버 like API 연동
- [ ] Pre-blurred 이미지 최적화
