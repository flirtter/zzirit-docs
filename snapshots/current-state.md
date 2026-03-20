# Current State

- generated_at: `2026-03-20 18:00 KST`
- memory_repo: `/Users/user/zzirit-docs`

## Active repositories
- zzirit-rn: `main` @ latest (clean)
- zzirit-docs: `main` @ latest (clean)

## zzirit-rn (3/20 작업 내역)

- **브랜치**: `main`
- **상태**: clean (커밋 완료, push 완료)
- **최근 커밋 (3/20 세션)**:
  1. my-edit rebuild — 프로필 편집 15개 필드 전면 재구성
  2. photo confirm modal — 사진 선택 확인 모달 추가
  3. chat location — NaverMapView 인라인 프리뷰 + 캐싱 최적화
  4. profile detail — 프로필 상세 화면 개선
  5. demo data fallback — 좋아요 탭 데모 데이터 폴백
  6. likes blur + bolt payment — 블러 처리 + 볼트 결제 시스템
  7. simplify — 코드 정리 및 단순화

### 3/20 핵심 변경
- `my-edit.tsx` — 프로필 편집 15개 필드 (닉네임, 직업, 키, 체형, 음주, 흡연, MBTI, 종교, 관심사 등) 전면 재구성
- `photo-confirm-modal` — 사진 선택 후 확인 모달 추가
- `chattingroom.tsx` — 위치 메시지 NaverMapView 인라인 프리뷰, 우측 정렬 수정, Unknown User Firestore 프로필 조회
- `likes.tsx` — 블러 처리 + 볼트 결제, 데모 데이터 폴백, AsyncStorage 구매 상태 영속화
- `lightning` — 프로필 카드 피드 높이 조정

## Surface snapshot
- `login`: state=`implemented`, qa=`onboarding_appium`, automation=`partial`
- `onboarding`: state=`implemented`, qa=`host_qa`, automation=`high`
- `my`: state=`design_matched`, qa=`host_qa`, automation=`high`
- `likes`: state=`doing`, qa=`host_qa`, automation=`high`
- `meeting`: state=`implemented`, qa=`host_qa`, automation=`high`
- `chat`: state=`design_matched`, qa=`host_qa`, automation=`high`
- `lightning`: state=`doing`, qa=`manual`, automation=`low`

## 미해결 이슈
- Like 블러/결제 실 서버 연동 (현재 클라이언트 데모 상태)
- 매칭 알림 + 매칭 목록 미구현
- ~~번개탭 마커/목록 이미지 불일치~~ → 수정 완료 (user_id hash 기반)
- 번개탭 프로필 카드 Figma 매칭 계속 (액션버튼 오버레이, 키워드칩)
- 커스텀 카메라 UI (Figma MY.png 기준) 미구현
- 칩 컴포넌트 공유 모듈 추출 필요 (my-edit <-> onboarding)
- StaticMapPreview 서버 프록시 기반 전환 필요
- createOrGetChatRoom O(n) -> pair_key 인덱스 최적화 필요

## 기술 메모
- 현재 유저 UID: `YativJyC3hR2SAU6Kq5R5ArgU33`
- 볼트 잔액: 10,090
- 시뮬레이터: iPhone 16 Pro (iOS 18.3), Metro 8081
- git-lfs 설치 완료 (zzirit-docs 이미지 LFS 추적)
