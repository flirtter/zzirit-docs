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

- Release capture exists, but it still covers the three top-level tabs only.
- Unlock dialog and preview modal still rely on Appium review evidence rather than release-only capture.

## Done Criteria

- Received, sent, and ZZIRIT tabs all render with real seeded data.
- Unlock and preview modal are stable in Appium.
- Likes host QA must emit both Appium and release-capture evidence.
