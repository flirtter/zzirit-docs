---
tags:
  - reference
  - api
up: "[[Knowledge]]"
created: 2026-03-20
---

# ZZIRIT API 명세서

> 앱(zzirit-rn) ↔ 서버(zzirit-api) 간 통합 API 계약.
> 이 문서가 **단일 진실 공급원(SSOT)** 이다.

## 기본 정보

| 항목 | 값 |
|------|-----|
| Base URL (dev) | `http://localhost:8080` |
| Base URL (prod) | `https://zzirit-api-147227137514.asia-northeast3.run.app` |
| 인증 | `Authorization: Bearer <Firebase_ID_Token>` |
| 인증 (dev) | `X-User-Id: <Firebase_UID>` |
| Content-Type | `application/json` |

---

## 갭 분석 요약

### 🔴 Critical (서비스 불가)

| # | 갭 | 현상 | 해결 |
|---|-----|------|------|
| G1 | profile 스키마 불일치 | 서버 profile: `name, sex, image_url, job, school, company, keywords`. 앱 profile: `nickname, age, gender, mbti, height, body_type, drinking, alcohol, religion, dating_style, ideal_type, profile_images, status_message, profile_completion` + 15개 필드 | 서버 profile 스키마를 앱 기준으로 확장 |
| G2 | get_nearby_profiles 조인 누락 | location 컬렉션만 반환 → profile 필드(age, job, keywords, image) 없음 | location + profile 조인 쿼리 구현 |
| G3 | 프로필 이중 쓰기 | 앱이 Firestore 직접 쓰기 + 서버 API 별도 존재 → 데이터 불일치 | 서버 API를 SSOT로 통일, 앱은 API만 호출 |

### 🟡 Medium (기능 제한)

| # | 갭 | 현상 | 해결 |
|---|-----|------|------|
| G4 | like 응답 필드명 불일치 | 서버: `name, image_url` / 앱: `nickname, profile_image` | 서버 응답을 앱 기대 필드명으로 통일 |
| G5 | chat 이중 시스템 | 앱: Firestore(rooms) + Realtime DB(messages) / 서버: Firestore only | Realtime DB 메시징 유지 (실시간 성능), 서버 chat API는 room 메타만 관리 |
| G6 | match에 chat_room_id 누락 | 앱이 match에서 chat_room_id 기대하지만 서버 미반환 | match 생성 시 chat_room 자동 생성 + ID 포함 |

### 🟢 Low (개선 사항)

| # | 갭 | 해결 |
|---|-----|------|
| G7 | createOrGetChatRoom O(n) 스캔 | pair_key 인덱스 추가 |
| G8 | 데모 데이터 자동 생성 로직 잔존 | 서버에서 제거, 별도 시드 스크립트로 분리 |

---

## 엔드포인트 명세

### Auth

앱이 Firebase Auth를 직접 사용 (서버 경유 안 함). 서버는 미들웨어에서 토큰 검증만.

| 엔드포인트 | 메서드 | 인증 | 설명 |
|-----------|--------|------|------|
| Firebase Auth SDK | - | - | 이메일/카카오/애플 로그인 |
| `POST /auth/send-verification` | POST | - | 이메일 인증코드 발송 (zzirit-proxy 경유) |

> **결정**: 소셜 로그인 후 Firestore `users` 컬렉션 쓰기는 앱이 직접 수행 (현행 유지).
> 이유: 인증 직후 즉시 유저 문서 생성 필요, 서버 왕복 불필요.

---

### Profile ⭐ (G1, G3 해결)

**원칙**: 서버 API가 profile CRUD의 SSOT. 앱은 Firestore 직접 쓰기 중단.

| 엔드포인트 | 메서드 | 인증 | 요청 | 응답 |
|-----------|--------|------|------|------|
| `GET /profile/get` | GET | ✅ | `?profile_id={uid}` | Profile 객체 |
| `POST /profile/create` | POST | ✅ | Profile 전체 필드 | `{profile_id}` |
| `POST /profile/update` | POST | ✅ | 변경할 필드만 | `{message}` |
| `DELETE /profile/delete` | DELETE | ✅ | `?profile_id={uid}` | `{message}` |

**Profile 객체** (앱 기준 통합 스키마):

```json
{
  "profile_id": "string (= user_id)",
  "nickname": "string",
  "age": "number",
  "gender": "string | null",         // "남성", "여성"
  "job": "string | null",
  "mbti": "string | null",           // "INTJ" 등
  "keywords": ["string"],            // 관심사 태그
  "height": "number | null",         // cm
  "height_range": "string | null",   // "170~175" 등
  "body_type": "string | null",      // "보통", "마름" 등
  "drinking": "string | null",       // "가끔", "자주" 등
  "alcohol": ["string"],             // 선호 주종
  "religion": "string | null",
  "dating_style": ["string"],
  "ideal_type": ["string"],
  "profile_images": ["string"],      // Firebase Storage URL 배열
  "status_message": "string | null",
  "profile_completion": "number",    // 0-100
  "created_at": "ISO 8601",
  "updated_at": "ISO 8601"
}
```

> **마이그레이션**: 서버 `name` → `nickname`, `sex` → `gender`, `image_url` → `profile_images[0]`, `message` → `status_message`.
> 신규 필드 추가: `age, mbti, height, height_range, body_type, drinking, alcohol, religion, dating_style, ideal_type, profile_completion`.

---

### Location & Nearby ⭐ (G2 해결)

| 엔드포인트 | 메서드 | 인증 | 요청 | 응답 |
|-----------|--------|------|------|------|
| `POST /location/upsert` | POST | ✅ | `{user_id, latitude, longitude, share_location?}` | `{success}` |
| `POST /location/share` | POST | ✅ | `{user_id, share_location}` | `{success}` |
| `GET /location/get_nearby_profiles` | GET | ✅ | `?latitude&longitude&radius&limit` | NearbyUser[] |
| `GET /location/get_nearby_meetings` | GET | ✅ | `?latitude&longitude&radius&limit` | NearbyMeeting[] |

**NearbyUser 응답** (location + profile 조인):

```json
{
  "user_id": "string",
  "nickname": "string",
  "age": "number",
  "gender": "string",
  "job": "string | null",
  "keywords": ["string"],
  "profile_image": "string | null",  // profile_images[0]
  "status_message": "string | null",
  "latitude": "number",
  "longitude": "number",
  "distance_m": "number"             // 계산된 거리 (미터)
}
```

> **서버 변경 필요**:
> 1. location 조회 후 profile 컬렉션 batch get으로 조인
> 2. 응답 필드를 위 스키마로 매핑
> 3. `share_location=false`인 유저 필터
> 4. 데모 자동생성 로직 제거

**NearbyMeeting 응답**:

```json
{
  "meeting_id": "string",
  "title": "string",
  "category": "string",
  "category_emoji": "string",
  "author_name": "string",
  "author_image_url": "string",
  "location_name": "string",
  "latitude": "number",
  "longitude": "number",
  "max_participants": "number",
  "current_participants": "number",
  "detailed_date": "string",
  "distance_m": "number"
}
```

---

### Like & Match ⭐ (G4, G6 해결)

| 엔드포인트 | 메서드 | 인증 | 요청 | 응답 |
|-----------|--------|------|------|------|
| `POST /like/send` | POST | ✅ | `{target_uid}` | `{matched, match_id?, chat_room_id?}` |
| `GET /like/received` | GET | ✅ | - | `{likes: LikeUser[], total}` |
| `GET /like/sent` | GET | ✅ | - | `{likes: LikeUser[], total}` |
| `POST /like/purchase-view` | POST | ✅ | - | `{success, remaining_bolts}` |
| `GET /match/list` | GET | ✅ | - | `{matches: MatchUser[], total}` |

**LikeUser 응답** (통일 필드명):

```json
{
  "user_id": "string",
  "nickname": "string",
  "age": "number",
  "job": "string | null",
  "profile_image": "string | null",
  "liked_at": "ISO 8601"
}
```

**MatchUser 응답**:

```json
{
  "user_id": "string",
  "nickname": "string",
  "age": "number",
  "job": "string | null",
  "profile_image": "string | null",
  "matched_at": "ISO 8601",
  "chat_room_id": "string"
}
```

> **서버 변경 필요**:
> 1. like/received, like/sent 응답에서 profile 조인 시 `nickname, age, job, profile_images[0]` 사용
> 2. match 생성 시 chat_room 자동 생성 → `chat_room_id` 포함 반환
> 3. 필드명 `name` → `nickname`, `image_url` → `profile_image`

---

### Bolt

| 엔드포인트 | 메서드 | 인증 | 요청 | 응답 |
|-----------|--------|------|------|------|
| `GET /bolt/balance` | GET | ✅ | - | `{balance, free_likes, free_chats}` |
| `GET /bolt/history` | GET | ✅ | `?type=all\|charge\|use` | `{items: BoltHistoryItem[], total}` |
| `POST /bolt/use` | POST | ✅ | `{amount, description?}` | `{success, remaining_bolts}` |
| `POST /bolt/charge` | POST | ✅ | `{amount, description?}` | `{success, balance}` |

> 현행 서버 구현과 앱 기대가 일치. **변경 불필요**.

---

### Meeting

| 엔드포인트 | 메서드 | 인증 | 요청 | 응답 |
|-----------|--------|------|------|------|
| `POST /meeting/create` | POST | ✅ | CreateMeeting 필드 | `{meeting_id}` |
| `GET /meeting/get` | GET | - | `?meeting_id` | Meeting 객체 |
| `GET /meeting/list` | GET | - | `?category&gender&limit` | Meeting[] |
| `POST /meeting/update` | POST | ✅ | `{meeting_id, ...fields}` | `{message}` |
| `POST /meeting/close` | POST | ✅ | `{meeting_id}` | `{message}` |
| `DELETE /meeting/delete` | DELETE | ✅ | `?meeting_id` | `{message}` |
| `POST /meeting/view` | POST | ✅ | `{meeting_id}` | `{message}` |

> 현행 서버 구현과 앱 기대가 대체로 일치. **변경 불필요**.

---

### Chat (G5 결정)

**아키텍처 결정**: 하이브리드 유지
- **chat_rooms**: Firestore (서버 API로 CRUD)
- **messages**: Firebase Realtime Database (앱 직접, 실시간 성능)
- **서버 역할**: room 메타데이터 관리, 앱 역할: 메시지 읽기/쓰기

| 엔드포인트 | 메서드 | 인증 | 요청 | 응답 |
|-----------|--------|------|------|------|
| `POST /chatroom/create` | POST | ✅ | `{chatroom_id, member_list}` | `{message}` |
| `GET /chatroom/get` | GET | ✅ | `?chatroom_id` | ChatRoom 객체 |
| `POST /chatroom/update` | POST | ✅ | `{chatroom_id, last_message?}` | `{message}` |

> 앱이 현재 Firestore 직접 chat_room 생성 중 (chatService.ts).
> **중기 목표**: 서버 API로 이관하여 pair_key 중복 체크 + O(1) 조회 구현 (G7).

---

### User (내부용)

| 엔드포인트 | 메서드 | 인증 | 설명 |
|-----------|--------|------|------|
| `POST /user/create` | POST | - | 유저 생성 (앱 → Firestore 직접) |
| `GET /user/get` | GET | - | 유저 조회 |
| `POST /user/update` | POST | - | 유저 업데이트 |
| `DELETE /user/delete` | DELETE | - | 유저 삭제 |

> 앱이 `users` 컬렉션 직접 관리 중 (authService.ts). 현행 유지.

---

## 서버 수정 우선순위

### Phase 1 — 즉시 (앱 동작에 필수)
1. **profile 스키마 확장** — 앱 필드 15개 수용
2. **get_nearby_profiles 조인** — location + profile batch join
3. **like/match 응답 필드명** — nickname, profile_image 통일
4. **match 시 chat_room_id 반환**

### Phase 2 — 단기
5. profile API를 앱 SSOT로 전환 (앱 Firestore 직접 쓰기 제거)
6. 데모 데이터 자동생성 제거
7. pair_key 기반 chat_room 중복 체크

### Phase 3 — 중기
8. AsyncStorage 결제 상태 → 서버 사이드 검증
9. 채팅 room 생성을 서버 API로 이관
10. StaticMapPreview 서버 프록시
