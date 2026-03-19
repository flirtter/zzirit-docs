# ZZIRIT Design Map

개별 화면 이미지와 서비스 플로우 이미지의 매핑.
에이전트(design-review, qa-automation)가 구현 참조 시 이 문서를 기준으로 사용.

## 수동 디자인 참조
- [[manual/catalog|수동 디자인 카탈로그]]

## 사용법

- **개별 화면 구현**: `screens/{surface}/{screen-id}.png` 참조
- **서비스 흐름 이해**: `flows/{surface}/` 의 큰 이미지에서 화면 간 연결 확인
- **기획 스펙**: `references/surface-specs/{surface}.md` 참조

---

## 1. Onboarding (온보딩)

### Flow Image
- `flows/` 없음 — 기획서 Figma의 "0. 온보딩 스펙 명세" 참조

### Service Flow
```
splash-01/02 → onboarding-entry (4종 배경 랜덤)
  ├→ [이메일] → onboarding-01~04 (이메일→인증번호→비밀번호)
  ├→ [카카오] → 카카오톡 앱 → 가입/로그인
  └→ [애플] → OS 설정 → 가입/로그인
→ onboarding-05 (이름 입력)
→ onboarding-06 (서비스 설명)
→ location-permission/01/02 (위치 권한)
→ onboarding-07~08 (사진 접근 권한)
→ onboarding-09 (프로필 사진 업로드)
→ notification-permission/01~06 (알림 허용)
→ onboarding-10 (프로필 소개 입력)
→ onboarding-11 (가입 완료) → 번개탭 진입
```

### Screens (33개)
| Screen ID | 파일 | 화면 설명 |
|-----------|------|----------|
| splash-01 | `screens/onboarding/splash-01.png` | 스플래시 1 |
| splash-02 | `screens/onboarding/splash-02.png` | 스플래시 2 |
| onboarding-entry | `screens/onboarding/onboarding-entry.png` | 로그인/회원가입 엔트리 (1x) |
| onboarding-01 ~ 11 | `screens/onboarding/onboarding-*.png` | 온보딩 단계별 화면 (1x) |
| onboarding-01-2x ~ 09-2x | `screens/onboarding/onboarding-*-2x.png` | 동일 화면 2x 버전 |
| notification-permission | `screens/onboarding/notification-permission.png` | 알림 허용 기본 |
| notification-permission-01~06 | `screens/onboarding/notification-permission-*.png` | 알림 허용 변형 |
| location-permission | `screens/onboarding/location-permission.png` | 위치 허용 기본 |
| location-permission-01~02 | `screens/onboarding/location-permission-*.png` | 위치 허용 변형 |

---

## 2. Lightning (번개)

### Flow Image
- `flows/lightning/lightning-flow.png` (13344x3708) — 번개탭 전체 흐름도

### Service Flow
```
lightning-location-popup (위치 허용 팝업)
  ├→ [허용] → lightning-map (지도 + 버블)
  └→ [거부] → lightning-location-denied → lightning-null
lightning-map
  ├→ [번개버블 탭] → lightning-list-view → lightning-list-expanded (만남 목록)
  │   └→ [프로필 탭] → lightning-profile-card-01/02/03 (프로필 카드)
  │       └→ [클릭] → lightning-profile-detail / lightning-profile-detail-full
  ├→ [미팅버블 탭] → meeting-bubble-detail (미팅 상세)
  └→ [내 위치 버튼] → 지도 중심 이동
```

### Screens (17개)
| Screen ID | 파일 | 화면 설명 |
|-----------|------|----------|
| lightning-map | `screens/lightning/lightning-map.png` | 지도 + 버블 메인 |
| lightning-map-alt | `screens/lightning/lightning-map-alt.png` | 지도 변형 |
| lightning-map-bubbles | `screens/lightning/lightning-map-bubbles.png` | 버블 표시 |
| lightning-profile-list | `screens/lightning/lightning-profile-list.png` | 번개 만남 목록 |
| lightning-profile-card | `screens/lightning/lightning-profile-card.png` | 프로필 카드 |
| lightning-profile-card-01~03 | `screens/lightning/lightning-profile-card-*.png` | 프로필 카드 변형 |
| lightning-profile-detail | `screens/lightning/lightning-profile-detail.png` | 프로필 상세 |
| lightning-profile-detail-full | `screens/lightning/lightning-profile-detail-full.png` | 프로필 상세 전체 |
| lightning-list-view | `screens/lightning/lightning-list-view.png` | 목록 50% 레이어 |
| lightning-list-expanded | `screens/lightning/lightning-list-expanded.png` | 목록 확장 |
| lightning-variant | `screens/lightning/lightning-variant.png` | 기타 변형 |
| lightning-location-popup | `screens/lightning/lightning-location-popup.png` | 위치 허용 팝업 |
| lightning-location-denied | `screens/lightning/lightning-location-denied.png` | 위치 거부 화면 |
| lightning-null | `screens/lightning/lightning-null.png` | 빈 화면 |
| lightning-meeting-overlay | `screens/lightning/lightning-meeting-overlay.png` | 미팅 오버레이 |

---

## 3. Meeting (미팅/소개팅)

### Flow Image
- 없음 — 기획서 Figma "2. 미팅/소개팅탭 스펙 명세" 참조

### Service Flow
```
meeting-list (목록)
  ├→ [필터] → meeting-list-filtered
  ├→ [글 탭] → meeting-detail (상세)
  │   ├→ [채팅하기] → 무료/유료 팝업 → 채팅방
  │   └→ [모집마감] → meeting-detail-closed
  └→ [등록 버튼] → meeting-create → meeting-create-full
meeting-bubble-on-map (번개탭 지도에서)
  └→ [미팅버블 탭] → meeting-bubble-detail
```

### Screens (10개)
| Screen ID | 파일 | 화면 설명 |
|-----------|------|----------|
| meeting-list | `screens/meeting/meeting-list.png` | 미팅 목록 |
| meeting-list-filtered | `screens/meeting/meeting-list-filtered.png` | 필터 적용 |
| meeting-detail | `screens/meeting/meeting-detail.png` | 글 상세 |
| meeting-detail-closed | `screens/meeting/meeting-detail-closed.png` | 모집 마감 |
| meeting-detail-with-chat | `screens/meeting/meeting-detail-with-chat.png` | 상세+채팅 |
| meeting-create | `screens/meeting/meeting-create.png` | 올리기 화면 |
| meeting-create-full | `screens/meeting/meeting-create-full.png` | 올리기 전체 |
| meeting-create-full-alt | `screens/meeting/meeting-create-full-alt.png` | 올리기 변형 |
| meeting-bubble-on-map | `screens/meeting/meeting-bubble-on-map.png` | 지도 위 미팅 |
| meeting-bubble-detail | `screens/meeting/meeting-bubble-detail.png` | 버블 상세 |

---

## 4. Chat (채팅)

### Flow Image
- `flows/chat/chat-flow.png` (6092x2964) — 채팅 흐름도

### Service Flow
```
chat-list (대화 목록, 최근 메시지 순)
  └→ [채팅방 탭] → chat-room-empty (메시지 없을 때, 프로필 크게)
      ├→ [예시 버블 탭] → chat-room-messages (대화 시작)
      ├→ [+] → chat-room-photo (사진) / chat-room-location (위치)
      ├→ chat-room-keyboard (키보드 올림)
      └→ chat-room-full (대화 진행 중)
chat-room-match (찌릿 매칭 채팅방, 별도 스킨)
chat-room-profile (프로필 바로가기)
```

### Screens (13개)
| Screen ID | 파일 | 화면 설명 |
|-----------|------|----------|
| chat-list | `screens/chat/chat-list.png` | 대화 목록 |
| chat-room-empty | `screens/chat/chat-room-empty.png` | 빈 채팅방 (프로필 크게) |
| chat-room-empty-state | `screens/chat/chat-room-empty-state.png` | 빈 상태 |
| chat-room-messages | `screens/chat/chat-room-messages.png` | 대화 중 |
| chat-room-variant-01 | `screens/chat/chat-room-variant-01.png` | 변형 1 |
| chat-room-variant-02 | `screens/chat/chat-room-variant-02.png` | 변형 2 |
| chat-room-photo | `screens/chat/chat-room-photo.png` | 사진 첨부 |
| chat-room-location | `screens/chat/chat-room-location.png` | 위치 첨부 |
| chat-room-full | `screens/chat/chat-room-full.png` | 전체 대화 |
| chat-room-minimal | `screens/chat/chat-room-minimal.png` | 최소 상태 |
| chat-room-match | `screens/chat/chat-room-match.png` | 찌릿 매칭 채팅방 |
| chat-room-profile | `screens/chat/chat-room-profile.png` | 프로필 연결 |
| chat-room-keyboard | `screens/chat/chat-room-keyboard.png` | 키보드 활성 |

---

## 5. MY

### Flow Images
- `flows/my/my-flow.png` (2496x2772) — MY탭 전체 흐름
- `flows/my/my-bolt-flow.png` (3028x3444) — 볼트 과금 흐름

### Service Flow
```
my-home / my-home-with-like (MY 홈)
  ├→ [미리보기] → 프로필 카드 (lightning 참조)
  ├→ [수정하기] → my-profile-edit-01/02 → my-profile-edit-full
  │   ├→ [사진] → my-profile-edit-photo-action → my-camera / my-photo-gallery
  │   │   └→ my-camera-preview
  │   └→ [수정하기 버튼] → 저장
  ├→ [볼트 >] → bolt-history / bolt-history-charge / bolt-history-usage
  ├→ [충전하기] → bolt-charge / bolt-charge-alt
  ├→ [Like >] → likes 화면 (아래 참조)
  ├→ [내 위치] → 위치 설정 화면
  ├→ [작성글] → 내 미팅글 목록
  └→ [설정 ⚙️] → my-settings → my-account-manage / my-app-info / my-terms / my-policy
```

### Screens (17개)
| Screen ID | 파일 | 화면 설명 |
|-----------|------|----------|
| my-home | `screens/my/my-home.png` | MY 홈 |
| my-home-with-like | `screens/my/my-home-with-like.png` | MY 홈 (Like 썸네일 포함) |
| my-profile-edit-01 | `screens/my/my-profile-edit-01.png` | 프로필 수정 상단 |
| my-profile-edit-02 | `screens/my/my-profile-edit-02.png` | 프로필 수정 변형 |
| my-profile-edit-full | `screens/my/my-profile-edit-full.png` | 프로필 수정 전체 (스크롤) |
| my-profile-edit-photos | `screens/my/my-profile-edit-photos.png` | 사진 4장 상태 |
| my-profile-edit-photo-action | `screens/my/my-profile-edit-photo-action.png` | 사진 찍기/선택 액션시트 |
| my-camera | `screens/my/my-camera.png` | 카메라 |
| my-camera-preview | `screens/my/my-camera-preview.png` | 카메라 미리보기 |
| my-photo-gallery | `screens/my/my-photo-gallery.png` | 갤러리 선택 |
| my-placeholder | `screens/my/my-placeholder.png` | 플레이스홀더 |
| my-settings | `screens/my/my-settings.png` | 설정 |
| my-settings-wip | `screens/my/my-settings-wip.png` | 설정 (작업예정) |
| my-account-manage | `screens/my/my-account-manage.png` | 계정 관리 |
| my-app-info | `screens/my/my-app-info.png` | 앱 정보 |
| my-terms | `screens/my/my-terms.png` | 이용약관 |
| my-policy | `screens/my/my-policy.png` | 운영 정책 |

---

## 6. Likes (좋아요)

### Flow
MY 홈 → Like > → Like 화면 (받은/보낸/ZZIRIT 탭)

### Service Flow
```
my-home [Like 섹션]
  ├→ 받은 Like 썸네일 (블러/정상)
  ├→ 보낸 Like 썸네일
  └→ [> 또는 More] → Like 화면
      ├→ [받은 Like 탭] → my-like-received-blur (미구매자)
      │   └→ [확인하기] → 볼트 차감 팝업 → 정상 노출
      ├→ [보낸 Like 탭] → my-like-sent
      └→ [ZZIRIT 탭] → 매칭 목록
```

### Screens (5개)
| Screen ID | 파일 | 화면 설명 |
|-----------|------|----------|
| my-like-received-blur | `screens/likes/my-like-received-blur.png` | 받은 Like (블러, 미구매자) |
| my-like-received-blur-alt | `screens/likes/my-like-received-blur-alt.png` | 받은 Like 변형 |
| my-like-sent | `screens/likes/my-like-sent.png` | 보낸 Like |
| my-like-received-female | `screens/likes/my-like-received-female.png` | 받은 Like (여성 뷰) |
| my-like-received-female-alt | `screens/likes/my-like-received-female-alt.png` | 여성 뷰 변형 |

---

## 7. Billing (볼트/과금)

### Flow Image
- `flows/my/my-bolt-flow.png` — 볼트 과금 흐름

### Service Flow
```
[좋아요 20회 초과] → 볼트 차감 팝업 (10볼트)
[채팅방 5회 초과] → 볼트 차감 팝업 (15볼트)
[받은 Like 보기] → 볼트 차감 팝업 (15볼트/1회, 120볼트/1시간)
[볼트 부족] → 충전 유도 팝업 → bolt-charge
MY 홈 → [충전하기] → bolt-charge
MY 홈 → [볼트 >] → bolt-history
```

### Screens (5개)
| Screen ID | 파일 | 화면 설명 |
|-----------|------|----------|
| bolt-charge | `screens/billing/bolt-charge.png` | 볼트 충전 화면 |
| bolt-charge-alt | `screens/billing/bolt-charge-alt.png` | 충전 변형 |
| bolt-history | `screens/billing/bolt-history.png` | 이용 내역 (전체) |
| bolt-history-charge | `screens/billing/bolt-history-charge.png` | 이용 내역 (충전탭) |
| bolt-history-usage | `screens/billing/bolt-history-usage.png` | 이용 내역 (사용탭) |

---

## 8. Moderation (신고/징계)

### Service Flow
```
[신고] → 사유 선택 (6종) → 접수
[주의] → moderation-warning-popup (홈 팝업)
[이용정지] → moderation-ban-popup → 기능 제한
[계정삭제] → 로그아웃 + 이메일 안내
```

### Screens (2개)
| Screen ID | 파일 | 화면 설명 |
|-----------|------|----------|
| moderation-warning-popup | `screens/moderation/moderation-warning-popup.png` | 주의/정지 팝업 |
| moderation-ban-popup | `screens/moderation/moderation-ban-popup.png` | 이용제한 팝업 |

---

## 전체 서비스 진입 플로우 (탭 네비게이션)

```
[앱 실행]
  → 스플래시 (N초)
  → 미가입: 온보딩 플로우 (15단계)
  → 기가입: 로그인 → 메인
  
[메인 - 하단 4탭]
  ├── ⚡ 번개 (lightning) — 지도 + 버블 + 프로필 카드 + 매칭
  ├── 👥 미팅 (meeting) — 목록 + 상세 + 올리기 + 채팅하기
  ├── 💬 채팅 (chat) — 대화 목록 + 1:1 채팅방 + 첨부
  └── 👤 MY (my) — 프로필 + 볼트 + Like + 위치 + 작성글 + 설정

[크로스 surface 연결]
  번개 프로필 카드 → [좋아요] → likes (볼트 차감)
  번개 프로필 카드 → [채팅하기] → chat (볼트 차감)
  미팅 상세 → [채팅하기] → chat (볼트 차감)
  서로 Like → 매칭 → chat (무료)
  MY → Like → likes
  MY → 볼트 → billing
```

---

## 파일 구조

```
figma-exports/
├── DESIGN-MAP.md          ← 이 문서
├── screen-catalog.json    ← 102개 화면 메타데이터
├── screens/               ← 개별 화면 이미지 (구현 참조용)
│   ├── onboarding/ (33)
│   ├── lightning/ (17)
│   ├── meeting/ (10)
│   ├── chat/ (13)
│   ├── my/ (17)
│   ├── likes/ (5)
│   ├── billing/ (5)
│   └── moderation/ (2)
└── flows/                 ← 서비스 흐름도 (큰 이미지)
    ├── lightning/lightning-flow.png
    ├── chat/chat-flow.png
    └── my/my-flow.png, my-bolt-flow.png
```
