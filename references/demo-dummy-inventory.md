# Demo / Dummy / Mock 데이터 인벤토리

> 생성: 2026-03-20 | zzirit-rn 기준

프로덕션 출시 전 제거하거나 실 서버 연동으로 교체해야 하는 모든 데모/더미 코드 목록.

---

## 1. 핵심 데모 데이터 소스

### `services/demoData.ts`
| 항목 | 내용 | 실제 구현 |
|------|------|-----------|
| UNSPLASH_IMAGES (10개) | 데모 프로필 사진 URL | Firestore `profileImages` 필드에서 로드 |
| DEMO_PROFILES (10명) | 합성 여성 프로필 (김다영, 서지수 등) | Firestore `profile` 컬렉션 |
| DEMO_RECEIVED_LIKES | 8건 모의 좋아요 | `likeService.getReceivedLikes()` API |
| DEMO_SENT_LIKES | 5건 모의 보낸 좋아요 | `likeService.getSentLikes()` API |
| DEMO_MATCHES | 2건 모의 매칭 | `likeService.getMatchList()` API |
| getDemoReceivedLikes/Sent/Match | 폴백 getter 함수들 | API 응답으로 대체 |

### `scripts/seedDemoData.ts`
- Firestore에 데모 프로필/좋아요/매칭 시드
- `isDemo: true` 플래그로 마킹
- **프로덕션 제거 필수** (또는 `__DEV__` 게이트)

---

## 2. 화면별 데모 사용처

### 번개탭 (`app/(tabs)/index.tsx` + `services/naverMapService.ts`)
| 위치 | 동작 | 실제 구현 |
|------|------|-----------|
| `naverMapService.ts` isPlaceholderUrl | 서버가 placeholder URL 반환 시 UNSPLASH 이미지로 대체 | 서버에서 실제 이미지 URL 반환 |
| `naverMapService.ts` stablePhotoIndex | user_id 해시로 데모 사진 결정 | 서버 image_url 그대로 사용 |
| `demoMarkerImages.ts` | Unsplash URL → 번들 원형 PNG 매핑 | FileSystem.downloadAsync로 실제 이미지 다운로드 |
| `assets/images/demo/demo_0~9.png` | 10개 번들 원형 마커 이미지 (약 450KB) | 제거, 실제 이미지 캐시 사용 |

### 좋아요탭 (`app/likes.tsx`)
| 위치 | 동작 | 실제 구현 |
|------|------|-----------|
| 받은좋아요 폴백 | API 빈 응답 시 `getDemoReceivedLikes()` | API 정상 응답 보장 + 빈 상태 UI |
| 보낸좋아요 폴백 | API 빈 응답 시 `getDemoSentLikes()` | 동일 |
| 매칭 폴백 | API 빈 응답 시 `getDemoMatchList()` | 동일 |
| 에러 폴백 | catch에서 3종 데모 데이터 전부 로드 | 에러 UI 표시 |
| DUMMY_DISTANCES | 하드코딩 거리 `['0.5km', '0.8km', ...]` | 서버에서 실제 거리 계산 |

### MY탭 (`app/(tabs)/my.tsx`)
| 위치 | 동작 | 실제 구현 |
|------|------|-----------|
| 받은좋아요 폴백 | API 빈 응답 시 `getDemoReceivedLikes()` | API 정상 응답 보장 |
| 블러/언블러 | AsyncStorage `LIKE_VIEW_PURCHASED` | 서버 사이드 결제 상태 확인 |

### 설정 (`app/settings.tsx`)
| 위치 | 동작 | 실제 구현 |
|------|------|-----------|
| "데모 프로필 시드" 버튼 | seedDemoData() 호출 | `__DEV__` 게이트 또는 제거 |
| "미팅 시드 데이터 생성" 버튼 | seedMeetings() 호출 | `__DEV__` 게이트 또는 제거 |
| "데모 데이터 삭제" 버튼 | clearDemoData() 호출 | `__DEV__` 게이트 또는 제거 |

---

## 3. 결제 상태 모킹

| 키 | 위치 | 현재 동작 | 실제 구현 |
|----|------|-----------|-----------|
| `LIKE_VIEW_PURCHASED` | likes.tsx, my.tsx | AsyncStorage에 구매 상태 저장 | 서버 사이드 결제 검증 (유저 조작 방지) |

---

## 4. `__DEV__` 조건부 경로

| 파일 | 용도 | 프로덕션 동작 |
|------|------|---------------|
| `config/api.ts` | dev: localhost:8080, prod: Cloud Run | 정상 — 유지 |
| `naverMapService.ts` | dev: X-User-Id 헤더, prod: Bearer 토큰 | 정상 — 유지 |

---

## 5. 안전한 폴백 (유지 가능)

| 항목 | 용도 |
|------|------|
| `profile-image.png` | 프로필 이미지 없을 때 기본 아바타 |
| `null-image.png` | 프로필 화면 이미지 없음 표시 |
| `resolveProfileImage()` | URL → 로컬 → 폴백 순서 결정 |

---

## 6. 프로덕션 체크리스트

- [ ] 서버 API가 실제 유저 데이터 안정적으로 반환 확인
- [ ] `demoData.ts` 의존성 제거 (likes, my, naverMapService)
- [ ] `seedDemoData.ts` + 설정 버튼 `__DEV__` 게이트 적용
- [ ] `demoMarkerImages.ts` + `demo_0~9.png` 번들 제거
- [ ] `isPlaceholderUrl` + `stablePhotoIndex` 로직 제거
- [ ] AsyncStorage 결제 상태 → 서버 사이드 검증 전환
- [ ] Firestore `isDemo` 필드 정리
- [ ] 에러 시 데모 폴백 대신 에러 UI 표시
