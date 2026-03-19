---
surface: onboarding
spec_status: draft
qa_level: host_qa
automation_status: high
---

# Onboarding Surface Contract

## Source Order

1. User-provided onboarding reference strip from this thread
2. Latest successful remote Appium run:
   - `/Users/user/zzirit-v2/artifacts/appium-onboarding/20260314-104826/summary.md`
3. Current implementation targets:
   - `/Users/user/zzirit-v2/apps/mobile/app/onboarding/profile-setup.tsx`
   - `/Users/user/zzirit-v2/apps/mobile/components/onboarding/steps/*`
   - `/Users/user/zzirit-v2/apps/mobile/features/onboarding/onboarding-flow.ts`

## Canonical Flow

1. Nickname
2. Intro
3. Location permission
4. Photo intro
5. Photo upload
6. Notification
7. Basic info
8. Matching profile
9. Welcome
10. Tabs
11. MY
12. MY edit
13. Updated MY
14. Settings
15. Likes received
16. Likes sent

## Non-Negotiable Structure

- The flow must behave like a single guided onboarding, not disconnected forms.
- Photo upload must support library selection and crop before continuing.
- Basic info and matching profile are separate steps.
- Welcome transitions into the real tab shell.

## Data Rules

- Signup goes through real proxy auth routes.
- Uploaded photos use the real upload path.
- Location and profile steps persist to real user/profile endpoints.
- The flow must survive reinstall and resume cleanly in QA.

## QA Snapshot

- Latest remote Appium run reaches through likes tabs:
  `/Users/user/zzirit-v2/artifacts/appium-onboarding/20260314-104826/summary.md`
- Photo picker and crop path are now automated.
- Host QA for `my` depends on this flow.

## Known Gaps

- Release-only clean capture is still not the default for all post-onboarding states.
- Some resumed runs still depend on recovery logic rather than one-shot clean success.

## QA
- [[QA/QA|QA 현황]]

## Done Criteria

- A fresh install can reach tabs and post-onboarding MY states without manual help.
- The screenshot chain is deterministic enough for queue-driven host QA.
- Post-onboarding expansion screens are captured without stale-state leakage.

