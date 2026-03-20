---
tags:
  - QA
  - lightning
surface: lightning
severity: high
status: fixed
found_date: 2026-03-20
fixed_date: 2026-03-20
up: "[[QA]]"
---

# QA-001: 지도 마커 이미지 vs 하단 목록 이미지 불일치

## 현상

번개탭에서 지도 위 원형 프로필 마커에 표시되는 사진과 하단 번개 목록(LightningMeetingLayer)의 아바타 사진이 동일 유저임에도 다른 사진으로 표시됨.

## Figma 기준

`lightning-map-bubbles.png` 참조: 지도 원형 마커의 프로필 사진과 하단 목록의 아바타가 동일 유저에 대해 동일한 사진이어야 함.

## 근본 원인

**2가지 원인이 복합적으로 작용:**

### 원인 1: 데모 사진 할당이 배열 인덱스 기반

`naverMapService.ts`에서 서버가 placeholder URL을 반환할 경우 UNSPLASH 데모 사진으로 대체하는데, 이때 `idx` (서버 응답 배열 내 순서)를 사용:

```typescript
// AS-IS (버그)
DEMO_PROFILE_PHOTOS[idx % DEMO_PROFILE_PHOTOS.length]
```

카메라 이동/새로고침 시 서버가 다른 순서로 유저를 반환하면, **동일 유저가 다른 사진**을 받게 됨.

### 원인 2: 이미지 프리캐시 레이스 컨디션

`index.tsx`에서 `mapMarkerUsers`를 설정하기 전에 `Image.prefetch()`를 await하는 동안, `apiData.users`가 이미 새 데이터로 업데이트됨. 하단 목록은 즉시 새 데이터를 표시하지만, 지도 마커는 프리캐시 완료까지 이전 데이터를 보여줌.

## 수정 내용

### Fix 1: user_id 해시 기반 안정적 사진 할당

```typescript
// TO-BE (수정)
const stablePhotoIndex = (userId: string): number => {
  let hash = 0;
  for (let i = 0; i < userId.length; i++) {
    hash = ((hash << 5) - hash + userId.charCodeAt(i)) | 0;
  }
  return Math.abs(hash) % DEMO_PROFILE_PHOTOS.length;
};
DEMO_PROFILE_PHOTOS[stablePhotoIndex(user.user_id)]
```

### Fix 2: 프리캐시 제거, 즉시 마커 설정

`UserMarker` 컴포넌트가 자체적으로 `FileSystem.downloadAsync`로 이미지를 캐싱하므로, `index.tsx`의 `Image.prefetch` 게이트를 제거하고 즉시 `mapMarkerUsers` 설정.

## 영향 파일

- `services/naverMapService.ts` — stablePhotoIndex 도입
- `app/(tabs)/index.tsx` — prefetch 레이스 컨디션 제거

## 검증 방법

1. 번개탭 진입 → 지도 마커 사진과 하단 목록 아바타 비교
2. 지도 카메라 이동 후 재로딩 → 동일 유저의 사진이 변경되지 않는지 확인
3. 마커 탭 → 프로필 카드의 사진이 목록/마커와 일치하는지 확인
