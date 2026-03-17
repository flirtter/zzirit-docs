# iOS Agent Scratchpad

## Current Task: Final Build & Launch on iPhone 17 (Mac Studio)

### 🔴 Issue Detected: Build Failed (2026-03-17)
- **Error**: `PhaseScriptExecution [CP-User] [Hermes] Replace Hermes for the right configuration, if needed` failed.
- **Context**: Occurred during `npx expo run:ios` on Mac Studio.
- **Root Cause Analysis**: Likely corrupted `DerivedData` or stale symlinks in the `hermes-engine` pod.

### 🛠️ Mitigation Plan
1. Delete `~/Library/Developer/Xcode/DerivedData/zziritrn-*`.
2. Clean `ios/Pods` and `ios/build`.
3. Re-run `pod install`.
4. Re-attempt `npx expo run:ios`.

### Status
- [ ] Environment Cleaned
- [ ] Pods Reinstalled
- [ ] Build Retried
