# Current State

- generated_at: `2026-03-19 17:00 KST`
- memory_repo: `/Users/user/zzirit-docs`

## Active repositories
- zzirit-rn: `main` @ `dae9204` (clean)
- zzirit-docs: `main` @ latest (clean)

## zzirit-rn (3/19 작업 내역)

- **브랜치**: `main`
- **상태**: clean (커밋 완료, push 완료)
- **최근 커밋 (3/19 세션 1~3)**:
  1. `7b8c3ef` 번개탭 바텀시트 3단 스냅
  2. `b382832` 프로필 상세 Figma 매칭
  3. `a873c24` 프로필 상세 뒤로 버튼 + 사진 비율 4:5
  4. `42b1aab` LightningProfileCard 디자인 통일
  5. `f192d1e` ProfileCardView 공통 컴포넌트 추출
  6. `3ccbf27` simplify 리뷰 반영
  7. `3316df6` 미팅 채팅 볼트 차감 + UserMarker 이미지 유틸
  8. `845a93f` 좋아요/채팅 실제 API 연결
  9. `55da6ff` profile-detail 훅 순서 에러 수정
  10. `dae9204` 채팅 디자인 파리티 + 통합 이미지 서비스

### 세션3 (dae9204) 핵심 변경
- `chattingroom.tsx` — 첨부 메뉴 세로 리스트, 전송 버튼 초록, 카메라 에러 처리, 위치 연동, 지도 프리뷰, 뒤로가기 수정
- `location_picker.tsx` — 헤더 "위치 보내기", X 제거, back 수정
- `location_viewer.tsx` — (신규) in-app 네이버 지도 위치 뷰어
- `imagePickerService.ts` — (신규) 통합 이미지 서비스 (3:4 + 1:1 이중 저장)
- `chatService.ts` — (신규) 채팅방 생성 + 볼트 차감

## Surface snapshot
- `login`: state=`implemented`, qa=`onboarding_appium`, automation=`partial`
- `onboarding`: state=`implemented`, qa=`host_qa`, automation=`high`
- `my`: state=`design_matched`, qa=`host_qa`, automation=`high`
- `likes`: state=`implemented`, qa=`host_qa`, automation=`high`
- `meeting`: state=`implemented`, qa=`host_qa`, automation=`high`
- `chat`: state=`design_matched`, qa=`host_qa`, automation=`high`
- `lightning`: state=`implemented`, qa=`manual`, automation=`low`

## 미해결 이슈
- MY 탭 Like 카드 0건 — 앱이 프로덕션 API 연결 중 (로컬 API 미연결)
- 채팅방 "Unknown User" → 상대방 이름 표시 필요
- 매칭 알림 + 매칭 목록 미구현
- 번개탭 실시간 위치 업데이트 (현재 10분 주기)
- 프로필 편집 → Firestore 반영 미구현

## 기술 메모
- 현재 유저 UID: `YativJyC3hR2SAU6Kq5R5ArgU33`
- 볼트 잔액: 10,090
- 시뮬레이터: iPhone 16 Pro (iOS 18.3), Metro 8081
- git-lfs 설치 완료 (zzirit-docs 이미지 LFS 추적)
