---
surface: chat
spec_status: stable
qa_level: host_qa
automation_status: high
design_parity: matched
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

## 2026-03-20 변경사항

- ✅ 위치 프리뷰 수정: NaverMapView 인라인 프리뷰 + 캐싱 최적화 (StaticMapPreview 기반)
- ✅ Unknown User 해결: Firestore 프로필 조회로 상대방 이름 표시
- ✅ 메시지 정렬 수정: 본인 메시지 우측 정렬 올바르게 동작

## Known Gaps

- ~~Release clean capture still needs to replace raw/dev review captures in the design gate.~~ → Resolved (dae9204)
- ~~Strict design parity is still weaker than `meeting/my`.~~ → Resolved: 6건 디자인 파리티 수정 (dae9204)
- ~~채팅방 "Unknown User" → 상대방 이름 표시 필요~~ → Resolved (2026-03-20): Firestore 프로필 조회
- 커스텀 사진 크롭 UI (Figma "취소"/"완료" 스타일) 미구현 — 현재 iOS 기본 크롭 제거 후 원본 사용
- StaticMapPreview → 서버 프록시 기반 Static Map 이미지 전환 필요

## Done Criteria (2026-03-20 갱신)

- ✅ 첨부 메뉴 세로 리스트 (Figma 매칭)
- ✅ 위치 전송 location_picker 연동
- ✅ 위치 메시지 Naver Static Map 프리뷰
- ✅ 위치 확인 in-app NaverMapView
- ✅ 전송 버튼 초록 활성화
- ✅ 카메라 에러 처리
- ✅ 통합 이미지 서비스 (3:4 + 1:1 이중 저장)
- ✅ Unknown User → Firestore 프로필 조회 (2026-03-20)
- ✅ 위치 프리뷰 NaverMapView 인라인 + 캐싱 (2026-03-20)
- ✅ 메시지 우측 정렬 수정 (2026-03-20)
- [ ] 커스텀 크롭 UI
