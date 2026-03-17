---
surface: login
spec_status: stable
qa_level: onboarding_appium
automation_status: partial
---

# Login Surface Spec

## Canonical Routes
- `/login` - 엔트리 (4종 배경 랜덤)
- `/login/email` - 이메일 입력
- `/login/email/verify` - 인증번호 입력
- `/login/email/password-create` - 비밀번호 만들기 (회원가입)
- `/login/email/password-input` - 비밀번호 입력 (로그인)
- `/login/find/find-account` - 비밀번호 찾기
- `/signup` - 회원가입 플로우

## 엔트리 화면
- 배경 이미지 4종 랜덤
- 버튼 3개: 이메일로 시작, 카카오로 시작, 애플 아이디로 시작

## 이메일 플로우
1. 이메일 입력 → 형식 검증
2. 기가입: 비밀번호 입력 → 로그인
3. 미가입: 인증번호(6자리, 5분) → 비밀번호 만들기 → 온보딩

## 소셜 로그인
- 카카오: 앱 열기 팝업 → 카카오톡 앱 → 가입/로그인
- 애플: iOS only → OS 설정 → 가입/로그인

## 비밀번호 찾기
1. 이메일 입력 (3번 스펙 동일)
2. 인증번호 (4번 스펙 동일)
3. 비밀번호 재설정 (5번 스펙 동일)

## Known Gaps
- 소셜 로그인: live-account 검증 미완
- PortOne 비밀번호 복구: 실 provider 미설정
