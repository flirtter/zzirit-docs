---
date: 2026-03-20
type: handover
session_id: s7-final
---

## 이번 세션 요약

s7은 매우 긴 세션. API 재정의 → 시드 데이터 → QA → 버그 수정 → 회고 루프 구축까지 진행.

### 완료 작업

**1. API/DB 재정의**
- `references/api-spec.md` — 앱↔서버 갭 8항목, 엔드포인트 계약 정의
- `03. Area/Database/firestore-schema.md` — Firestore 운영 SSOT
- 서버 4파일 수정: profileModel/Bo, locationController/Dao/Bo, likeController

**2. 시드 데이터 시스템**
- `scripts/seed_data.py` — 프로필 10명, 모임 6개, 좋아요/매칭/볼트/채팅 24개
- Firebase Storage + 번들 이미지 동기화
- UID 환경변수 지원, 메인 유저 프로필 수정 금지 규칙

**3. RN 앱 수정 (20+ 커밋)**
- s5/s6 미커밋 변경 전부 커밋 (프로필 편집, 채팅, 좋아요 등)
- API URL Cloud Run 통일, settings.tsx 빌드 에러 수정
- naverMapService 필드 매핑, UserMarker 번들 이미지
- BottomTabBar 아이콘 수정, profileImages 객체 배열 처리
- 미사용 더미 데이터 전면 삭제 (24파일, 712줄)
- LightningProfileCard 복원 + 카드 높이 82% 조정
- 온보딩 라우팅 수정, 사진 업로드 실패 시 자동 진행
- 마커 클릭 → 프로필 매칭 state 타이밍 수정
- getFirstProfileImageUrl 유틸 추출 (중복 3곳 → 1곳)

**4. 서버 수정 (12+ 커밋)**
- profile 스키마 15필드 확장 + 레거시 호환
- geohash 프리픽스 범위 쿼리 (정확 매칭 → 프리픽스)
- meetings 컬렉션 + GeoPoint 지원
- like/match 필드 통일 + chatroom 자동 생성
- app/utils.py 누락 수정 (503 크래시)
- .gitignore 2534→25줄, .env 추적 해제

**5. 문서 + 회고 루프**
- README 전면 재작성 (5분 세팅 가이드)
- 회고 인덱스 (`retro-index.md`) + 리그레션 체크리스트
- 핸드오버 템플릿에 교훈/근본원인 섹션 추가
- CLAUDE.md에 retro-index 로드 순서 + 핵심 규칙 추가
- 필드 네이밍 맵, 시드 데이터 가이드

## 교훈 (Lessons Learned)

1. **한 커밋 = 한 목적** — 마커 수정 커밋에 프로필 카드 레이아웃을 같이 넣어서 리그레션 발생
2. **변경 후 전체 플로우 테스트** — 마커만 확인하고 카드 드래깅/상세 진입 테스트 안 함
3. **실 유저 데이터 절대 덮어쓰기 금지** — 시드 스크립트가 유저 프로필을 가짜 값으로 덮어쓴 실수
4. **이미지 소스 통일** — randomuser.me 2회 호출로 마커/카드 이미지 불일치
5. **UID 확인 필수** — 시뮬레이터 UID가 세 번 변경됨 (YativJy → ycSU5D → Tg5Mo)

## 근본 원인 분석

**프로필 카드 리그레션**: 커밋 8ab5b5b에서 범위 초과 변경. `pagingEnabled` 제거, 카드 높이 변경, ReportBottomSheet 삭제. → 복원 + retro 문서 작성으로 해결.

**마커/카드 이미지 불일치**: 번들 PNG와 Firebase Storage URL이 다른 randomuser.me 호출에서 옴. → Storage에 번들 이미지 업로드로 동기화.

## 미완료 TODO

### 긴급 (다음 세션 첫 번째)
- [ ] **ProfileCardView 통일 컴포넌트** — 번개탭/미팅탭/마이 전부 동일 포맷
  - 버튼(X/하트/보내기)이 카드 사진 위 오버레이 (Figma 참고 이미지 기준)
  - 카드 ~82% 높이, 다음 유저 peek 노출
  - 번개탭: 클릭한 유저로 시작, 스크롤로 다른 유저 탐색
  - 어디서 프로필 클릭해도 동일한 카드 포맷

### 중기
- [ ] 앱 Firestore 직접 읽기 → 서버 API 전환 (Phase 2)
- [ ] 필드 네이밍 이중화 해소 ([[field-naming-map]])
- [ ] 매칭 알림 + 매칭 목록 UI
- [ ] 커스텀 카메라 UI (Figma MY.png)
- [ ] AsyncStorage 결제 상태 → 서버 사이드 검증
- [ ] createOrGetChatRoom pair_key 최적화
- [ ] FileSystem.downloadAsync 실패 디버깅 (시뮬레이터 환경)
- [ ] 시드 이미지 고해상도 소스 확보 (randomuser.me 128px 한계)

## 다음 세션 추천 작업

> 시작 시 [[retro-index]] 리그레션 체크리스트 확인.

1. **ProfileCardView 통일** — Figma 참고 이미지 기반, 번개/미팅/마이 공유 컴포넌트
2. **번개탭 카드 피드** — 클릭 유저로 시작 + 스크롤 + peek + 배경 투명
3. **시드 이미지 품질** — 고해상도 인물 사진 확보 (Unsplash API 등)
