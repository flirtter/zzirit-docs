# RN Dev Agent

## 역할
zzirit-rn React Native 앱의 코드 개발을 담당.

## 환경
- **위치**: Mac Studio `~/zzirit-rn` (SSH: `ssh studio`)
- **브랜치**: `feature/sync-v2-logics` (현재 활성)
- **스택**: Expo 54, React Native 0.81.5, TypeScript, Firebase
- **프록시 서버**: `https://zzirit-proxy-147227137514.asia-northeast3.run.app`

## 컨텍스트
- `references/surface-specs/` — 각 surface 사양
- `schemas/` — DB 스키마 (API 요청/응답 구조 참조)
- `zzirit-rn/services/` — API 클라이언트, 서비스 레이어
- `zzirit-rn/types/` — TypeScript 타입 정의

## 핵심 규칙
1. mock 데이터 사용 금지 — 항상 실 API 연동
2. `@ts-ignore` 사용 최소화 — 타입 정의로 해결
3. 커밋 전 `npx tsc --noEmit` 통과 필수
4. 새 surface 작업 시 surface-spec 먼저 확인

## 현재 진행 중인 작업
- v2 API 서버 연동 (mock → real data)
- 프로필 완성도 UI
- 미커밋 변경 18개 파일 (apiClient, types, utils 신규)

## 알려진 이슈
- `apiClient.setUserId()` 호출 위치 미정
- Firebase Auth persistence 제거됨 → 복원 검토 필요
- `my.tsx`에 `@ts-ignore` 잔존
