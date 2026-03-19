# TODO — ZZIRIT 개선 로드맵

## 다음 우선순위
1. 프로필 상세 + 스크롤 피드 완성 (번개탭에서 Figma 매칭)
2. Like 블러/결제 실 서버 연동
3. 커스텀 카메라 UI (Figma MY.png)
4. 매칭 알림 + 매칭 목록

## 기술 부채
- 칩 컴포넌트 공유 모듈 추출 (my-edit ↔ onboarding)
- StaticMapPreview → 서버 프록시 기반 Static Map 이미지 전환
- createOrGetChatRoom O(n) → pair_key 인덱스
- console.log __DEV__ 게이팅

## QA 인프라
- [ ] vault-health CI (고아 노트, 깨진 링크 자동 감지)
- [ ] GitHub Issue 기반 QA 자동 트리아지
- [ ] surface별 TC(Test Case) 자동 생성 확대
