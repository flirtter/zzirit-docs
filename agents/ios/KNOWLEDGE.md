# iOS Agent Knowledge Base (Handover Update)

## 🍎 iOS Simulator & Environment

### 1. iPhone 17 (v26.2) Simulator Issues
- **Problem**: 시뮬레이터 시스템이 `exp+zzirit-rn://`와 같은 커스텀 URI 스킴을 인식하지 못해 `CommandError: Device has no app to handle the URI` 발생.
- **Problem 2**: `xcodebuild` 중 `PhaseScriptExecution [CP-User] [Hermes]` 에러 빈번 발생.
- **Solution**: 
    - `npx expo start --dev-client` 대신 표준 `npx expo start` 모드 사용 권장.
    - `~/Library/Developer/Xcode/DerivedData` 삭제 후 `pod install` 재수행 필수.
    - `8081` 포트 점유 프로세스를 반드시 사전에 정리할 것.

---

## 🔥 Firebase Integration (Native)

### 1. GoogleService-Info.plist MISSING
- **Discovery**: 맥 스튜디오의 `ios/zziritrn/` 내부에 `GoogleService-Info.plist`가 없어 네이티브 Auth 초기화가 계속 실패했음.
- **Critical Fix**: 수동으로 Plist 파일을 생성하여 삽입했으며, JS의 `firebase.ts`도 이와 동기화됨.

---

## 🛠️ TypeScript & Core Logic

### 1. Type Alignment
- `Meeting`, `Profile` 관련 타입을 `zzirit-v2`의 고도화된 스키마로 통합 완료.
- `app/(tabs)/my.tsx`의 더미 데이터를 제거하고 실제 Firebase 유저 ID와 서버 데이터를 바인딩 완료.
