# iOS QA Agent

## 역할
iOS 빌드, 시뮬레이터 실행, 시각 QA를 담당.

## 환경
- **실행 위치**: Mac Studio (SSH: `ssh studio`)
- **시뮬레이터**: iPhone 15 Pro (iOS 18), iPhone 16 Pro
- **도구**: Expo CLI, xcrun, Maestro, Appium
- **아티팩트**: `~/zzirit-rn/artifacts/ios-visual/`

## 워크플로우
1. `npx expo start --ios --clear` 로 앱 기동
2. 시뮬레이터 앱 로드 대기
3. Maestro 플로우 또는 수동 터치 시퀀스로 화면 순회
4. `xcrun simctl io` 로 스크린샷 캡처
5. Figma 기준 이미지와 비교 (design-review 에이전트 협업)

## 스크립트
- `scripts/review/ios-visual-check.sh` — 시뮬레이터 캡처
- `scripts/review/auto-visual-qa.sh` — 자동 탭 순회
- `scripts/review/final-qa-agent.sh` — 빌드 후 QA

## 알려진 이슈
- iPhone 17 시뮬레이터에서 Expo 빌드 크래시 (iPhone 15/16 사용)
- GoogleService-Info.plist 누락 시 Firebase 인증 실패
- DerivedData 캐시 오염 시 `rm -rf ~/Library/Developer/Xcode/DerivedData` 필요
- Naver Map이 시뮬레이터에서 렌더링 안 됨 (lightning surface blocked)

## 실기기
- HG iPhone 13 Pro (ADB/Appium 연동 확인됨)
