# iOS Agent Knowledge Base

## 🍎 iOS Simulator & Environment

### 1. iPhone 17 (v26.2) Simulator Issues
- **Problem**: 시뮬레이터 시스템이 `exp+zzirit-rn://`와 같은 커스텀 URI 스킴을 인식하지 못해 `CommandError: Device has no app to handle the URI` 발생.
- **Solution**: 
    - `npx expo start --dev-client` 대신 표준 `npx expo start` 모드 사용 권장.
    - `osascript`를 사용한 `Cmd+R` 강제 리로드로 번들러 연결 유도.
    - 시뮬레이터 창이 백그라운드에 있을 경우 터치 명령이 무시되므로 항상 `osascript -e 'tell application "Simulator" to activate'` 먼저 수행.

### 2. Port Conflict (8081)
- **Insight**: 맥 스튜디오 환경에서는 여러 프로젝트(`zzirit-v2`, `zzirit-rn`)가 동일한 `8081` 포트를 경쟁함.
- **Solution**: 작업 시작 전 `lsof -ti:8081 | xargs kill -9`로 포트를 정화하고 시작할 것.

---

## 🔥 Firebase Integration

### 1. Native Authentication Failure
- **Problem**: `GoogleService-Info.plist` 파일이 `ios/zziritrn/` 폴더에 물리적으로 존재하지 않으면 JS 설정만으로는 Auth 초기화가 실패하거나 불안정함.
- **Solution**: 파일이 없을 경우 JS의 `apiKey` 등을 기반으로 수동 생성하거나, `firebase.ts`에서 `initializeAuth` 시 `getReactNativePersistence`를 확실히 설정할 것.

### 2. Firebase SDK Compatibility
- **Insight**: Expo SDK 54+ 환경에서는 `@react-native-firebase/auth`와 `firebase/auth` 간의 persistence 충돌이 잦음.
- **Best Practice**: `firebase/auth/react-native`에서 `getReactNativePersistence`를 사용하는 방식을 표준으로 유지.

---

## 🛠️ Build & Debugging

### 1. Hermes Engine Script Failure
- **Problem**: `xcodebuild` 중 `PhaseScriptExecution [CP-User] [Hermes]` 에러로 빌드 실패.
- **Solution**: `~/Library/Developer/Xcode/DerivedData`의 관련 폴더를 삭제하고 `pod install` 재수행.
