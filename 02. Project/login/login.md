---
surface: login
spec_status: draft
qa_level: onboarding_appium
automation_status: partial
---

# Login Surface Contract

## Source Order

1. User-provided entry/login/password-recovery reference images from this thread
2. Current implementation targets:
   - `/Users/user/zzirit-v2/apps/mobile/app/login/index.tsx`
   - `/Users/user/zzirit-v2/apps/mobile/app/login/email.tsx`
   - `/Users/user/zzirit-v2/apps/mobile/app/login/find/*`
   - `/Users/user/zzirit-v2/apps/mobile/app/signup.tsx`
3. Service/auth integration:
   - Firebase-backed session bootstrap
   - real proxy auth routes
   - Kakao + Apple client integrations

## Canonical Routes

- `/login`
- `/login/email`
- `/login/find/find-account`
- `/login/find/verify-method`
- `/login/find/verify-identity`
- `/signup`

## Non-Negotiable Structure

- Entry screen must preserve four theme variants with logo, hero image, and three CTA buttons.
- `Email start` routes to account existence check first.
- Unknown email continues to signup.
- Existing email continues to email login.
- Password recovery starts with email/id input before verification-method selection.
- Verification methods for password recovery are `Kakao` and `Phone`.

## Data Rules

- All login and signup mutations must target the real proxy backend.
- Social login uses provider tokens, not mock provider ids.
- Password recovery uses real identity verification config when available.
- If the provider is not configured in runtime, the screen must fail clearly, not silently.

## QA Snapshot

- Entry variants were manually iterated and aligned.
- Login and signup routes are covered as part of onboarding Appium flow.
- Dedicated login host QA does not exist yet.

## Known Gaps

- Social login and PortOne flows still need live-account confirmation.
- Password recovery visual flow is implemented, but provider live verification is not yet fully acceptance-tested.

## Done Criteria

- Entry themes stay aligned across device sizes.
- Email branching works: existing account -> login, unknown account -> signup.
- Password recovery follows the specified sequence without dead-end alerts.
- Dedicated login host QA can be promoted after spec confirmation.

