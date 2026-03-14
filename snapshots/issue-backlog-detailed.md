# Detailed Issue Backlog

자동화 큐와 surface spec을 합쳐, 실제 이슈를 더 잘게 나눌 수 있도록 만든 세부 backlog다.

## my-followup

- title: `My follow-up`
- section: `my`
- queue_status: `in_progress`
- follow_up_goal: `promote release clean capture for subroutes`

### Canonical Subroutes
- `/my`
- `/settings`
- `/account-management`
- `/my-edit`
- `/volt-charge`
- `/volt-history`
- `/my-location`
- `/my-posts`

### Known Gaps
- Some subroutes still rely on seeded review routing for the cleanest captures.
- Release capture parity for every MY subroute is not yet uniformly enforced.

### Done Criteria
- MY home, settings, account management, edit profile, and volt screens all preserve the design hierarchy.
- Host QA can exercise MY without stale onboarding state.
- The latest MY bundle can be reused as a design gate input.

## onboarding-followup

- title: `Onboarding follow-up`
- section: `onboarding`
- queue_status: `pending`
- follow_up_goal: `stabilize release-only capture path for post-onboarding expansion states`

### Canonical Flow
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

### Known Gaps
- Release-only clean capture is still not the default for all post-onboarding states.
- Some resumed runs still depend on recovery logic rather than one-shot clean success.

### Done Criteria
- A fresh install can reach tabs and post-onboarding MY states without manual help.
- The screenshot chain is deterministic enough for queue-driven host QA.
- Post-onboarding expansion screens are captured without stale-state leakage.

## login-followup

- title: `Login follow-up`
- section: `login`
- queue_status: `pending`
- follow_up_goal: `promote dedicated login host QA after spec confirmation`

### Canonical Routes
- `/login`
- `/login/email`
- `/login/find/find-account`
- `/login/find/verify-method`
- `/login/find/verify-identity`
- `/signup`

### Known Gaps
- Social login and PortOne flows still need live-account confirmation.
- Password recovery visual flow is implemented, but provider live verification is not yet fully acceptance-tested.

### Done Criteria
- Entry themes stay aligned across device sizes.
- Email branching works: existing account -> login, unknown account -> signup.
- Password recovery follows the specified sequence without dead-end alerts.
- Dedicated login host QA can be promoted after spec confirmation.

## meeting-followup

- title: `Meeting follow-up`
- section: `meeting`
- queue_status: `pending`
- follow_up_goal: `final spacing polish and release clean capture`

### Canonical Routes
- `/meeting`
- `/create-meeting`
- `/meeting-detail?id=<id>`

### Known Gaps
- Spacing and form density can still be tightened further against the design.
- Release-only clean capture path is not yet the sole source of truth.

### Done Criteria
- List, create, and detail all pass their dedicated Appium review.
- Host QA wrapper can reuse those artifacts without flaky permission-state divergence.
- Meeting can remain in `done` state without manual patching between runs.

## likes-followup

- title: `Likes follow-up`
- section: `likes`
- queue_status: `pending`
- follow_up_goal: `promote likes review into design gate with release captures`

### Canonical Tabs
- `received`
- `sent`
- `zzirit`

### Known Gaps
- Release capture exists, but it still covers the three top-level tabs only.
- Unlock dialog and preview modal still rely on Appium review evidence rather than release-only capture.

### Done Criteria
- Received, sent, and ZZIRIT tabs all render with real seeded data.
- Unlock and preview modal are stable in Appium.
- Likes host QA must emit both Appium and release-capture evidence.
