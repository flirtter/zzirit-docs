---
tags:
  - reference
  - operations
up: "[[Knowledge]]"
created: 2026-03-20
---

# 시드 데이터 운영 가이드

## 실행

```bash
cd zzirit-api
source venv/bin/activate
python3 scripts/seed_data.py          # 생성
python3 scripts/seed_data.py --clear  # 삭제
```

## 생성되는 데이터

| 항목 | 수량 | 위치 | 비고 |
|------|------|------|------|
| 프로필 | 10명 | Firestore `profile` | 15필드 전부 + 레거시 호환 필드 |
| 위치 | 10개 | Firestore `location` | 강남/홍대/역삼/선릉/합정 일대, geohash 포함 |
| 모임 | 6개 | Firestore `meetings` | 스터디/맛집/러닝/보드게임/전시/점심 |
| 받은 좋아요 | 5개 | Firestore `likes` | seed_user_01~05 → 메인 유저 |
| 보낸 좋아요 | 3개 | Firestore `likes` | 메인 유저 → seed_user_06~08 |
| 매칭 | 2건 | Firestore `matches` | 수빈, 준혁 (채팅방 자동 생성) |
| 채팅 메시지 | 24개 | RTDB `messages/{chatId}` | 수빈 13개(텍스트+이미지+위치), 준혁 11개 |
| 볼트 | 10,000 | Firestore `bolts` | 잔액 + 충전 히스토리 |
| 메인 유저 프로필 | 1개 | Firestore `profile` | MY 페이지 호환 필드 보강 |

## 시드 유저 목록

| ID | 이름 | 나이 | 직업 | 위치 | 관계 |
|----|------|------|------|------|------|
| seed_user_01 | 수빈 | 25 | 디자이너 | 강남역 | 매칭 + 채팅 |
| seed_user_02 | 준혁 | 28 | 개발자 | 신논현 | 매칭 + 채팅 |
| seed_user_03 | 하은 | 24 | 대학원생 | 홍대 | 받은 좋아요 |
| seed_user_04 | 민재 | 30 | 마케터 | 역삼 | 받은 좋아요 |
| seed_user_05 | 서연 | 26 | 간호사 | 선릉 | 받은 좋아요 |
| seed_user_06 | 도윤 | 27 | PM | 시청 | 보낸 좋아요 |
| seed_user_07 | 유진 | 23 | 대학생 | 합정 | 보낸 좋아요 |
| seed_user_08 | 시우 | 29 | 변호사 | 강남 | 보낸 좋아요 |
| seed_user_09 | 지아 | 25 | 프리랜서 | 삼성 | 프로필만 |
| seed_user_10 | 현우 | 31 | 셰프 | 논현 | 프로필만 |

## 채팅 메시지 형식

Firebase Realtime Database 경로: `messages/{chatRoomId}/{pushKey}`

```json
{
  "text": "안녕하세요!",
  "senderUid": "uid",
  "createdAt": 1234567890000,
  "type": "TEXT",
  "timestamp": 1234567890000
}
```

### 특수 메시지 타입

| 타입 | text 필드 형식 | 예시 |
|------|---------------|------|
| 텍스트 | 평문 | `"안녕하세요!"` |
| 이미지 | `[IMAGE]{url}` | `"[IMAGE]https://storage.../photo.jpg"` |
| 위치 | `[LOCATION]{주소}\|{위도}\|{경도}` | `"[LOCATION]국립현대미술관 서울\|37.5796\|126.9800"` |

## 프로필 이미지

Firebase Storage 경로: `profiles/demo_user_auto_{1~10}/profile.jpg`
버킷: `zzirit-location.firebasestorage.app`

s6 세션에서 Unsplash 인물 사진 10장을 업로드한 상태.
시드 프로필은 이 URL을 사용.

## 메인 유저 정보

- UID: `YativJyC3hR2SAU6Kq5R5ArgU33`
- 볼트 잔액: 10,000
- 프로필: 개발자, 27세, INTP

## 알려진 이슈

1. **필드 이중화**: 앱이 Firestore를 직접 읽는 곳에서 레거시 필드명 사용 → [[field-naming-map]] 참조
2. **geohash precision**: 저장은 precision 7, 쿼리는 5~6 → 프리픽스 범위 쿼리로 해결 (locationDao.py)
3. **get_nearby_meetings**: 기존 `posts` 컬렉션 → `meetings` 컬렉션으로 수정 완료
4. **채팅 메시지 중복**: 스크립트 재실행 시 RTDB push()로 메시지 중복 생성됨 → --clear 후 재실행 권장
