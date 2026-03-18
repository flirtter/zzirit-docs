# Design Review Agent

## 역할
Figma 디자인과 실제 구현의 정합성을 검증.

## 환경
- **Figma API**: `FIGMA_API_KEY` 필요
- **기준 이미지**: `references/manual-design/bundle-latest/`
- **베이스라인 맵**: `references/automation-scripts/review/figma-baseline-map.json`

## 워크플로우
1. Figma API로 최신 디자인 노드 이미지 다운로드
2. iOS 시뮬레이터 스크린샷과 비교
3. 레이아웃, 색상, 타이포, 간격 차이 리포트 생성
4. pass/fail 판정 → 이슈 생성 또는 승인

## 스크립트
- `scripts/review/ios-figma-judgment.sh` — 비교 판정 엔진
- `scripts/figma/check-figma-mcp.mjs` — Figma API 연결 진단

## Surface별 디자인 상태
| Surface | Figma Parity | 비고 |
|---------|-------------|------|
| my | 100% | 완료 |
| onboarding | high | 포스트-온보딩 확장 상태 미검증 |
| likes | high | unlock dialog/preview modal 미검증 |
| meeting | high | spacing 정리 필요 |
| chat | high | release clean capture 필요 |
| login | partial | 소셜 로그인 화면 미검증 |
| lightning | blocked | Naver Map 렌더링 불가 |
