---
surface: meeting
spec_status: draft
qa_level: host_qa
automation_status: high
---

# Meeting Surface Contract

## Source Order

1. Manual design bundle:
   - `/Users/user/zzirit-v2/artifacts/manual-design-references/latest/meeting`
2. Latest Appium review:
   - `/Users/user/zzirit-v2/artifacts/appium-meeting/20260314-100842/summary.md`
3. Latest host QA wrapper:
   - `/Users/user/zzirit-v2/artifacts/manual-review/meeting-host-qa-20260314-r5/focus-host-qa-summary.md`
4. Current implementation targets:
   - `/Users/user/zzirit-v2/apps/mobile/app/(tabs)/meeting.tsx`
   - `/Users/user/zzirit-v2/apps/mobile/app/create-meeting.tsx`
   - `/Users/user/zzirit-v2/apps/mobile/app/meeting-detail.tsx`

## Canonical Routes

- `/meeting`
- `/create-meeting`
- `/meeting-detail?id=<id>`

## Non-Negotiable Structure

- Meeting list is filter-first and card-based.
- Create meeting is a structured form with location selection, not a loose stack of inputs.
- Meeting detail must read like a social-event detail surface with author, metadata, body, and CTA hierarchy.

## Data Rules

- Review seed must provide multiple meeting cards.
- Meeting responses must normalize author and card metadata consistently.
- Location picker and detail route must work from seeded data.

## QA Snapshot

- Latest Appium review is success:
  `/Users/user/zzirit-v2/artifacts/appium-meeting/20260314-100842/summary.md`
- Host QA wrapper is success:
  `/Users/user/zzirit-v2/artifacts/manual-review/meeting-host-qa-20260314-r5/focus-host-qa-summary.md`
- Latest fresh manual capture set:
  `/Users/user/zzirit-v2/artifacts/manual-review/meeting-20260314-r3`

## Known Gaps

- Spacing and form density can still be tightened further against the design.
- Release-only clean capture path is not yet the sole source of truth.

## Done Criteria

- List, create, and detail all pass their dedicated Appium review.
- Host QA wrapper can reuse those artifacts without flaky permission-state divergence.
- Meeting can remain in `done` state without manual patching between runs.

