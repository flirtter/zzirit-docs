---
tags:
  - reference
  - api
up: "[[Knowledge]]"
created: 2026-03-20
---

# 필드 네이밍 맵 — 앱 vs 서버 vs Firestore

> 앱이 Firestore 직접 읽기하는 곳과 서버 API 응답의 필드명이 다르다.
> 이 불일치가 "데이터는 있는데 안 보이는" 주요 원인.

## Profile 필드 매핑

| 의미 | 서버 API (새) | 앱 Firestore 직접읽기 (레거시) | 비고 |
|------|--------------|-------------------------------|------|
| 닉네임 | `nickname` | `name` | ChatContext, my.tsx |
| 성별 | `gender` | `sex` | onboarding |
| 프로필 이미지 | `profile_images` (배열) | `image_url` (단일 문자열) | ChatContext: `profile.image_url` |
| 상태 메시지 | `status_message` | `statusMessage` | my.tsx |
| 나이 | `age` (직접 저장) | `birthYear` → 계산 | likeController |

## 어디서 어떤 필드를 쓰는가

### 앱 → Firestore 직접 읽기 (레거시 필드명 필요)

| 화면 | 파일 | 읽는 필드 |
|------|------|-----------|
| 채팅 목록 | `ChatContext.tsx:216-221` | `profile.name`, `profile.image_url` |
| MY 페이지 | `my.tsx` | `name`, `job`, `keywords`, `statusMessage`, `profileImages`, `image_url` |
| 프로필 상세 | `profile-detail.tsx` | `name`, `age`, `job`, `image_url` |

### 앱 → API 응답 매핑 (수정 완료)

| 화면 | 파일 | API 필드 → 앱 필드 | 상태 |
|------|------|-------------------|------|
| 번개탭 | `naverMapService.ts:68` | `nickname\|\|name` → `name` | ✅ 수정 완료 |
| 번개탭 | `naverMapService.ts:77` | `profile_image\|\|image_url` → `profileImageUrl` | ✅ 수정 완료 |

### 서버 API 응답 (새 필드명)

| API | 응답 필드 |
|-----|-----------|
| `GET /like/received` | `nickname`, `age`, `job`, `profile_image` |
| `GET /like/sent` | `nickname`, `age`, `job`, `profile_image` |
| `GET /match/list` | `nickname`, `age`, `job`, `profile_image`, `chat_room_id` |
| `GET /location/get_nearby_profiles` | `nickname`, `age`, `gender`, `job`, `keywords`, `profile_image`, `distance_m` |

## 해결 원칙

**단기 (현재)**: Firestore 프로필에 양쪽 필드명 모두 저장
```
nickname: "수빈"    +  name: "수빈"
profile_images: []  +  image_url: "..."
status_message: ""  +  statusMessage: ""
```

**중기 (Phase 2)**: 앱의 Firestore 직접 읽기를 서버 API로 전환
- ChatContext → API 또는 새 필드명으로 마이그레이션
- my.tsx → 서버 profile API 사용
- 이후 레거시 필드 제거

## 시드 데이터에서의 적용

`zzirit-api/scripts/seed_data.py`에서 양쪽 필드명 모두 포함:
```python
profile_data = {
    'nickname': '수빈',     # 새 필드
    'name': '수빈',         # 레거시 (ChatContext 호환)
    'profile_images': [url], # 새 필드
    'image_url': url,       # 레거시 (ChatContext 호환)
    ...
}
```
