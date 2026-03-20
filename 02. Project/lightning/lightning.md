---
surface: lightning
spec_status: doing
qa_level: manual
automation_status: low
---

# Lightning Surface Contract

## Source Order

1. Canonical spec: `references/surface-specs/lightning.md`
2. Current implementation:
   - `zzirit-rn/app/(tabs)/index.tsx` — 메인 화면 (지도 + 바텀시트)
   - `zzirit-rn/components/naverMap/UserMarker.tsx` — 원형 프로필 마커
   - `zzirit-rn/components/naverMap/AppointmentMarker.tsx` — 미팅 버블 마커
   - `zzirit-rn/components/lightning/LightningMeetingLayer.tsx` — 하단 번개 목록 시트
   - `zzirit-rn/components/lightning/LightningProfileCard.tsx` — 프로필 카드 피드
   - `zzirit-rn/services/naverMapService.ts` — API 호출 + 데이터 변환

## Current State (2026-03-20)

- 네이버 지도 렌더링 정상 동작 (iOS 시뮬레이터)
- 원형 프로필 마커 (Union.png 프레임 + 프로필 이미지) 표시
- 하단 번개 목록 시트: 3단 스냅 (collapsed/peek/expanded), 거리순/나이순 정렬
- 프로필 카드 피드: 상하 스와이프, X/좋아요/채팅 액션버튼
- Like API 연동 완료 (sendLike)
- Chat 연동 완료 (startChatAndNavigate)
- 데모 사진 할당 user_id 해시 기반으로 수정 (마커/목록 일치)

## Figma 디자인 레퍼런스

| 화면 | 파일 | 핵심 요소 |
|------|------|-----------|
| 지도+버블 | `lightning-map-bubbles.png` | 원형 노란테두리 마커, 하단 시트 peek |
| 프로필 카드 | `Group 33585.png` | 카드: 헤더(이름/나이/직업/거리) + 사진 + 키워드칩 + 액션버튼(X/하트/채팅) |
| 좋아요 확인 | `lightning-profile-list.png` | 3D 하트 아이콘 + "좋아요를 누를까요?" + 10볼트 차감 안내 |
| 채팅 확인 | `lightning-profile-card.png` | "채팅방을 만들까요?" + 15볼트 차감 안내 |
| 위치 미허용 | `lightning-location-denied.png` | 위치 허용 유도 |
| 볼트 부족 | `lightning-profile-detail.png` | "볼트가 부족해요" + 충전하기 버튼 |

### 프로필 카드 디자인 스펙 (Figma 기준)

- 배경: 투명 (지도 visible between cards)
- 카드: `borderRadius: 24`, white bg, shadow
- 헤더: 프로필 아바타(circle) + 이름 + 나이 + 직업 + "내 주위 X.Xkm" + more(...)
- 사진: full-width, rounded corners
- 키워드: 사진 위 오른쪽 하단 오버레이 (반투명 칩)
- 액션버튼: 사진 위 하단 오버레이 — X(dismiss), 노란하트(like), 초록채팅(send)
- 다음 카드: peek (헤더만 보임)
- 하단 탭바: 번개/미팅/채팅/MY 항상 visible

## Non-Negotiable Structure

- Map-first surface
- Nearby people and meetings on the same primary surface
- Bottom sheet/list anchored under the map
- Meaningful permission-missing fallback
- 지도 마커 ↔ 목록 ↔ 카드에서 동일 유저 = 동일 사진

## QA
- [[QA/QA|QA 현황]]

## Done Criteria

- Native map renders and drags reliably
- 원형 마커 이미지 = 목록 아바타 = 카드 사진 (일치)
- 프로필 카드 Figma 매칭 (액션버튼 오버레이, 키워드칩 오버레이)
- Like/Chat 서버 연동 + 볼트 차감 확인 다이얼로그
- 프로필 상세 진입 동작

