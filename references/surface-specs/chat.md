---
surface: chat
spec_status: draft
qa_level: host_qa
automation_status: high
---

# Chat Surface Contract

## Source Order

1. Manual design bundle:
   - `/Users/user/zzirit-v2/artifacts/manual-design-references/latest/chat`
2. Latest raw smoke summary:
   - `/Users/user/zzirit-v2/artifacts/manual-review/chat-raw-20260313-r9/summary.md`
3. Current implementation targets:
   - `/Users/user/zzirit-v2/apps/mobile/app/(tabs)/chatting.tsx`
   - `/Users/user/zzirit-v2/apps/mobile/app/chattingroom.tsx`
 - `/Users/user/zzirit-v2/apps/mobile/components/chat/*`
4. Latest host QA summary:
   - `/Users/user/zzirit-v2/artifacts/manual-review/chat-host-qa-20260314-121447-r3/focus-host-qa-summary.md`

## Canonical Routes

- `/chatting`
- `/chattingroom?id=<room-id>`

## Non-Negotiable Structure

- List rows must convey avatar, name, preview, unread/read state, and timestamp.
- Empty room, quick reply, image message, and location message all need distinct visual treatments.
- The room input bar must remain usable for text and media actions.

## Data Rules

- Review seed must create multiple rooms with different states.
- Last-message metadata must support read-pill and preview logic.
- Image/location preview cards must degrade gracefully if external thumbnails fail.

## QA Snapshot

- Host QA now covers:
  - Appium chat smoke
  - raw smoke fallback
- Raw smoke covers:
  - empty room
  - quick reply
  - location room
  - image room
  - gallery send attempt
- Latest host QA summary:
  `/Users/user/zzirit-v2/artifacts/manual-review/chat-host-qa-20260314-121447-r3/focus-host-qa-summary.md`
- Latest raw smoke summary:
  `/Users/user/zzirit-v2/artifacts/chat-raw/20260314-031649/summary.md`

## Known Gaps

- Release clean capture still needs to replace raw/dev review captures in the design gate.
- Strict design parity is still weaker than `meeting/my` because canonical node mapping is incomplete.

## Done Criteria

- Chat list and room spacing match the design bundle more closely.
- Gallery and location flows remain deterministic enough for host QA.
- Release capture and design gate reach the same level as `meeting/my`.
