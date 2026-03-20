---
tags:
  - reference
  - database
up: "[[Database]]"
created: 2026-03-20
---

# Firestore 컬렉션 스키마 (SSOT)

> 실제 Firestore 구현 기준. SQL 파일은 초기 설계 참고용, **이 문서가 운영 스키마의 SSOT**.
> 🔄 = 서버 수정 필요, ✅ = 현행 일치

---

## users ✅

> 앱(authService.ts)이 직접 Firestore에 쓰기. 서버 user API는 보조.

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| **doc ID** | string | - | Firebase Auth UID |
| kakao_id | string | - | 카카오 로그인 시 |
| apple_id | string | - | 애플 로그인 시 |
| provider | string | ✅ | `'email'`, `'kakao'`, `'apple'` |
| nickname | string | ✅ | 표시 닉네임 |
| email | string | - | 이메일 |
| profile_image_url | string | - | 대표 이미지 URL |
| identity_token | string | - | 애플 로그인 토큰 |
| authorization_code | string | - | 애플 인가 코드 |
| status | string | - | `'active'`, `'suspended'`, `'deleted'` |
| warning_count | number | - | 경고 횟수 |
| suspended_until | timestamp | - | 정지 만료일 |
| deleted | boolean | - | 탈퇴 여부 |
| deleted_at | timestamp | - | 탈퇴일 |
| created_at | timestamp | ✅ | serverTimestamp |
| updated_at | timestamp | ✅ | serverTimestamp |

---

## profile 🔄

> **현재**: 서버와 앱이 다른 필드 사용 → **서버 스키마를 앱 기준으로 확장**

| 필드 | 타입 | 필수 | 설명 | 서버 현재 | 변경 |
|------|------|------|------|-----------|------|
| **doc ID** | string | - | = user_id (profile_id) | ✅ | - |
| nickname | string | ✅ | 닉네임 | `name` | rename |
| age | number | ✅ | 나이 | ❌ | **추가** |
| gender | string | - | `"남성"`, `"여성"` | `sex` | rename |
| job | string | - | 직업 | ✅ | - |
| mbti | string | - | MBTI 4글자 | ❌ | **추가** |
| keywords | string[] | - | 관심사 태그 | ✅ | - |
| height | number | - | 키(cm) | ❌ | **추가** |
| height_range | string | - | `"170~175"` 등 | ❌ | **추가** |
| body_type | string | - | 체형 | ❌ | **추가** |
| drinking | string | - | 음주 빈도 | ❌ | **추가** |
| alcohol | string[] | - | 선호 주종 | ❌ | **추가** |
| religion | string | - | 종교 | ❌ | **추가** |
| dating_style | string[] | - | 데이팅 스타일 | ❌ | **추가** |
| ideal_type | string[] | - | 이상형 | ❌ | **추가** |
| profile_images | string[] | ✅ | Firebase Storage URL | `image_url` (단일) | **배열로 변경** |
| status_message | string | - | 상태 메시지 | `message` | rename |
| profile_completion | number | - | 완성도 (0-100) | ❌ | **추가** |
| created_at | string | ✅ | ISO 8601 | ✅ | - |
| updated_at | string | ✅ | ISO 8601 | ✅ | - |

### 제거할 서버 필드
- `school` → 앱 미사용, 제거
- `company` → 앱 미사용, 제거
- `current_location` → location 컬렉션이 담당, 제거

---

## location ✅

> 서버(locationController.py)가 관리. geohash 기반 근접 검색.

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| **doc ID** | string | - | = user_id |
| user_id | string | ✅ | Firebase UID |
| latitude | number | ✅ | 위도 |
| longitude | number | ✅ | 경도 |
| geohash | string | ✅ | 서버 자동 계산 |
| share_location | boolean | ✅ | 위치 공유 여부 |
| updated_at | string | ✅ | ISO 8601 |

---

## likes ✅

> 서버(likeController.py)가 관리.

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| **doc ID** | string | - | auto |
| from_uid | string | ✅ | 좋아요 보낸 유저 |
| to_uid | string | ✅ | 좋아요 받은 유저 |
| created_at | string | ✅ | ISO 8601 |

---

## matches 🔄

> match 생성 시 chat_room_id 포함 필요

| 필드 | 타입 | 필수 | 설명 | 변경 |
|------|------|------|------|------|
| **doc ID** | string | - | auto | - |
| users | string[] | ✅ | [user_a, user_b] 정렬 | - |
| user_a | string | ✅ | 첫 번째 유저 | - |
| user_b | string | ✅ | 두 번째 유저 | - |
| chat_room_id | string | ✅ | 매칭 시 자동 생성된 채팅방 | **추가** |
| matched_at | string | ✅ | ISO 8601 | - |

---

## meetings ✅

> 서버(meetingController.py)가 관리. 앱 기대와 대체로 일치.

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| **doc ID** | string | - | auto (meeting_id) |
| profile_id | string | ✅ | 작성자 UID |
| title | string | ✅ | 제목 |
| body | string | - | 본문 |
| category | string | - | 카테고리 |
| categoryEmoji | string | - | 이모지 |
| gender | string | - | `"남성"`, `"여성"`, `"무관"` |
| location_name | string | - | 장소명 |
| detailed_location | string | - | 상세 주소 |
| detailed_date | string | - | 일시 |
| is_negotiable | boolean | - | 협의 가능 |
| hashtags | string[] | - | 해시태그 |
| image_url | string | - | 이미지 |
| created_location | GeoPoint | - | lat/lng |
| max_participants | number | ✅ | 최대 인원 |
| current_participants | number | - | 현재 인원 |
| participants_list | string[] | - | 참가자 UID 배열 |
| status | string | ✅ | `OPEN`, `CLOSED`, `DELETED` |
| views | number | - | 조회수 |
| viewed_by | string[] | - | 조회 유저 배열 |
| created_at | string | ✅ | ISO 8601 |
| updated_at | string | ✅ | ISO 8601 |

---

## bolts ✅

> 서버(boltController.py)가 관리. 앱 기대와 일치.

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| **doc ID** | string | - | = user_id |
| balance | number | ✅ | 볼트 잔액 |
| free_likes | number | - | 무료 좋아요 잔여 |
| free_chats | number | - | 무료 채팅 잔여 |
| created_at | string | ✅ | ISO 8601 |

### bolt_history (서브컬렉션: `bolts/{uid}/entries`)

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| **doc ID** | string | - | auto |
| type | string | ✅ | `"charge"`, `"use"` |
| amount | number | ✅ | 금액 |
| description | string | - | 사유 |
| created_at | string | ✅ | ISO 8601 |

---

## chat_rooms ✅

> 앱(chatService.ts)이 Firestore 직접 생성. 중기적으로 서버 이관 예정.

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| **doc ID** | string | - | `{uid1}_{uid2}_{timestamp}` |
| chatroom_id | string | ✅ | = doc ID |
| profile_list | string[] | ✅ | 참가자 UID 배열 |
| last_message | string | - | 마지막 메시지 |
| last_message_at | timestamp | - | 마지막 메시지 시각 |
| created_at | timestamp | ✅ | 생성일 |

> **중기 개선**: `pair_key` 필드 추가 (`sort([uid1, uid2]).join('_')`) → 중복 방지 + O(1) 조회

---

## chat_messages (Firebase Realtime Database)

> Firestore가 아닌 RTDB 사용 (실시간 성능).
> 경로: `/chatrooms/{chatroom_id}/messages/{message_id}`

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| text | string | ✅ | 메시지 본문 |
| senderUid | string | ✅ | 발신자 UID |
| timestamp | number | ✅ | Unix timestamp |
| type | string | - | `"text"`, `"image"`, `"location"` |
| imageUrl | string | - | 이미지 URL |
| latitude | number | - | 위치 위도 |
| longitude | number | - | 위치 경도 |

---

## verification_codes ✅

> 앱(authService.ts)이 직접 Firestore에 쓰기.

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| **doc ID** | string | - | 이메일 |
| code | string | ✅ | 6자리 인증코드 |
| email | string | ✅ | 이메일 |
| expiresAt | timestamp | ✅ | 만료 시각 |
| createdAt | timestamp | ✅ | 생성 시각 |

---

## reports ✅ (미구현, 스키마 예약)

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| **doc ID** | string | - | auto |
| reporter_id | string | ✅ | 신고자 |
| target_id | string | ✅ | 대상 |
| target_type | string | ✅ | `"user"`, `"message"`, `"meeting"` |
| reason | string | ✅ | 사유 |
| description | string | - | 상세 설명 |
| status | string | - | `"pending"`, `"resolved"` |
| created_at | string | ✅ | ISO 8601 |

## blocks ✅ (미구현, 스키마 예약)

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| **doc ID** | string | - | `{blocker}_{blocked}` |
| blocker_id | string | ✅ | 차단자 |
| blocked_id | string | ✅ | 피차단자 |
| created_at | string | ✅ | ISO 8601 |

---

## Firebase Storage 경로

```
/profile-images/{userId}/{fileName}       ← 프로필 이미지 (주력)
/additional-images/{userId}/{fileName}    ← 추가 이미지
/users/{userId}/profile_{index}_{ts}.jpg  ← 온보딩 업로드
/public/{userId}.png                      ← 공개 이미지
```

---

## SQL → Firestore 마이그레이션 매핑

| SQL 파일 | Firestore 컬렉션 | 상태 |
|----------|-----------------|------|
| users.sql | `users` | ✅ 일치 (앱 직접관리) |
| profiles.sql | `profile` | 🔄 서버 필드 확장 필요 |
| locations.sql | `location` | ✅ 일치 |
| likes.sql | `likes` | ✅ 일치 |
| matches.sql | `matches` | 🔄 chat_room_id 추가 |
| meetings.sql | `meetings` | ✅ 일치 |
| bolts.sql | `bolts` + sub `entries` | ✅ 일치 |
| chats.sql | `chat_rooms` (Firestore) + RTDB messages | ✅ 일치 |
| lightning.sql | `location` 재사용 | ✅ |
| reports.sql | `reports` + `blocks` | 미구현 |
| uploads.sql | Firebase Storage 직접 | 별도 컬렉션 불필요 |
