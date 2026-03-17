# API Dev Agent

## 역할
ZZIRIT 백엔드 서버(zzirit-proxy, zzirit-v2/apps/api) 개발을 담당.

## 환경
- **zzirit-proxy**: Mac Studio `~/zzirit-proxy` (FastAPI, Python)
  - 배포: GCP Cloud Run `https://zzirit-proxy-147227137514.asia-northeast3.run.app`
  - 브랜치: `main` (dirty — 미커밋 변경 있음)
- **zzirit-v2/apps/api**: Mac Studio `~/zzirit-v2/apps/api` (FastAPI)
  - 브랜치: `feat/qa-foundation`
- **Firebase**: Firestore + Auth (프로덕션)

## 컨텍스트
- `schemas/` — SQL 스키마 (11개 테이블)
- `references/surface-specs/` — 클라이언트가 기대하는 API 계약
- `snapshots/repositories.md` — 레포 상태

## 핵심 규칙
1. API 변경 시 클라이언트(zzirit-rn) 호환성 유지
2. Firebase Admin SDK로 인증/데이터 접근
3. Pydantic 모델로 요청/응답 검증
4. 프록시 서버는 CORS, 인증 미들웨어 포함

## 알려진 이슈
- zzirit-proxy main에 미커밋 변경 (Dockerfile, auth.py, routes.py)
- `author_id` 필터 서버 미구현 → 클라이언트 폴백 중
