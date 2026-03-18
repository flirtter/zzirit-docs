---
surface: my
spec_status: draft
qa_level: host_qa
automation_status: high
---

# MY Surface Contract

## Source Order

1. Manual design bundle:
   - `/Users/user/zzirit-v2/artifacts/manual-design-references/latest/MY`
2. Latest MY host QA:
   - `/Users/user/zzirit-v2/artifacts/manual-review/my-host-qa-20260314-r2/focus-host-qa-summary.md`
3. Current implementation targets:
   - `/Users/user/zzirit-v2/apps/mobile/app/(tabs)/my.tsx`
   - `/Users/user/zzirit-v2/apps/mobile/app/settings.tsx`
   - `/Users/user/zzirit-v2/apps/mobile/app/account-management.tsx`
   - `/Users/user/zzirit-v2/apps/mobile/app/my-edit.tsx`
   - `/Users/user/zzirit-v2/apps/mobile/app/volt-charge.tsx`
   - `/Users/user/zzirit-v2/apps/mobile/app/volt-history.tsx`

## Canonical Subroutes

- `/my`
- `/settings`
- `/account-management`
- `/my-edit`
- `/volt-charge`
- `/volt-history`
- `/my-location`
- `/my-posts`

## Non-Negotiable Structure

- MY home must expose profile summary, likes summary, location, volt, posts, and settings entry points.
- `my-edit` must behave like an edit surface with photo management, not just a long raw form.
- Volt history and charge are dedicated screens, not inline cards only.

## Data Rules

- MY must prefer real seeded/review data over fake placeholders.
- If live values are missing, review seed data must still generate a design-meaningful layout.
- Photo ordering in `my-edit` must be preserved.

## QA Snapshot

- Host QA pass:
  `/Users/user/zzirit-v2/artifacts/manual-review/my-host-qa-20260314-r2/focus-host-qa-summary.md`
- Representative seeded captures:
  - `/Users/user/zzirit-v2/artifacts/manual-review/seeded-my-20260313-final/my-rebooted.png`
  - `/Users/user/zzirit-v2/artifacts/manual-review/seeded-my-20260313-final/settings-new.png`
  - `/Users/user/zzirit-v2/artifacts/manual-review/my-edit-20260313-refined-v2/my-edit-refined.png`

## Known Gaps

- Some subroutes still rely on seeded review routing for the cleanest captures.
- Release capture parity for every MY subroute is not yet uniformly enforced.

## Done Criteria

- MY home, settings, account management, edit profile, and volt screens all preserve the design hierarchy.
- Host QA can exercise MY without stale onboarding state.
- The latest MY bundle can be reused as a design gate input.

