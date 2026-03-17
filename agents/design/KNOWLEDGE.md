# Design Agent Knowledge Base

## Surface별 Figma Parity 현황

| Surface | Parity | 비고 |
|---------|--------|------|
| my | 100% | 완벽 달성 |
| onboarding | high | 포스트-온보딩 확장 상태 미검증 |
| likes | high | unlock dialog/preview modal 미검증 |
| meeting | high | spacing 정리 필요 |
| chat | high | release clean capture 필요 |
| login | partial | 소셜 로그인 화면 미검증 |
| lightning | blocked | Naver Map 시뮬레이터 렌더링 불가 |

## 디자인 레퍼런스
- 번들: references/manual-design/bundle-latest/ (19개 PNG + catalog)
- 베이스라인 맵: references/automation-scripts/review/figma-baseline-map.json

## 비교 방법
1. ios-figma-judgment.sh로 Figma API 이미지 다운 → iOS 스크린샷 대조
2. ZZIRIT_IOS_VISUAL_DECISION=pass|fail 로 수동 오버라이드 가능
