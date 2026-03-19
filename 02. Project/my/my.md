---
surface: my
spec_status: stable
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

## Profile Edit 15 Fields (2026-03-20 재구성)

`my-edit` 화면은 다음 15개 필드를 편집 가능하게 제공:
- 닉네임, 생년월일, 성별
- 직업, 학력
- 키, 체형
- 음주, 흡연
- MBTI, 종교
- 관심사 (다중 선택 칩)
- 자기소개
- 사진 관리 (최대 6장, 드래그 재정렬)
- 사진 선택 확인 모달 (photo confirm modal)

각 필드는 Figma MY.png 디자인에 매칭된 레이아웃으로 구성.
칩 기반 선택 UI는 onboarding과 동일 패턴 사용.

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

- 커스텀 카메라 UI (Figma MY.png 기준) 미구현 — 현재 expo-image-picker 기본 UI 사용
- 사진 크롭 UI 미구현 — Figma "취소"/"완료" 스타일 커스텀 크롭 pending
- 칩 컴포넌트 공유 모듈 추출 필요 (my-edit <-> onboarding 간 중복 코드)

## Done Criteria

- MY home, settings, account management, edit profile, and volt screens all preserve the design hierarchy.
- Host QA can exercise MY without stale onboarding state.
- The latest MY bundle can be reused as a design gate input.
- ✅ 프로필 편집 15필드 전면 재구성 완료 (2026-03-20)
- ✅ 사진 선택 확인 모달 추가 (2026-03-20)
