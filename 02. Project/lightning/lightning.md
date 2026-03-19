---
surface: lightning
spec_status: draft
qa_level: manual
automation_status: low
---

# Lightning Surface Contract

## Source Order

1. Existing lightning contract:
   - `/Users/user/zzirit-v2/docs/spec/lightning-screen-contract.md`
2. Legacy implementation baseline:
   - `/Users/user/zzirit-rn/app/(tabs)/map.tsx`
   - `/Users/user/zzirit-rn/components/naverMap/NaverMap.tsx`
3. Current implementation targets:
   - `/Users/user/zzirit-v2/apps/mobile/app/(tabs)/index.tsx`
   - `/Users/user/zzirit-v2/apps/mobile/components/naverMap/*`

## Current State

- Structure has been rebuilt toward the legacy map-first flow.
- Native Naver map runtime is still blocked by client-id/runtime verification issues.
- The user explicitly asked to leave lightning aside for now.

## Non-Negotiable Structure

- Map-first surface
- Nearby people and meetings on the same primary surface
- Bottom sheet/list anchored under the map
- Meaningful permission-missing fallback

## Known Blocker

- Naver map client/runtime mismatch prevents this from being a stable automation target.

## QA
- [[QA/QA|QA 현황]]

## Done Criteria

- Native map renders and drags reliably.
- Marker interactions match the intended people/meeting previews.
- Fresh route-accurate capture is available again.

