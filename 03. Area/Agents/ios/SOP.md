# Agent Self-Refinement SOP

이 문서는 모든 전문 에이전트가 실패로부터 학습하고 스스로의 지능을 높이기 위해 준수해야 하는 표준 절차입니다.

## 1. 실패 감지 및 기록 (The Crash Loop)
- 작업 도중 에러(`TypeError`, `Build Failed`, `Crash`)가 발생하면 즉시 하던 일을 멈춘다.
- `SCRATCHPAD.md`에 현재의 에러 메시지와 발생 상황을 있는 그대로 기록한다.

## 2. 근본 원인 분석 (Root Cause Analysis)
- 로그를 최소 3번 이상 다시 읽고, 단순한 오타인지 아니면 환경적 결함인지 판별한다.
- 분석된 원인을 `JOURNAL.md`에 **"Lesson Learned"** 섹션으로 요약한다.

## 3. 지식 전이 (Knowledge Transfer)
- 해결된 에러가 향후 재발할 가능성이 있다면, 즉시 해당 에이전트의 `KNOWLEDGE.md`에 **"Avoid this mistake"** 또는 **"Best Practice"**로 명문화한다.
- 만약 에러의 원인이 다른 에이전트(예: API 변경이 iOS 크래시 유발)에게 있다면, 해당 에이전트의 메모리 허브에도 지식을 전달한다.

## 4. SOP 업데이트
- 특정 작업 순서가 비효율적이거나 위험하다고 판단되면 `SOP.md`를 수정하여 더 안전한 절차로 변경한다.
- 예: "빌드 전 반드시 `8081` 포트 체크를 수행할 것" 등.

## 5. 최종 검증
- 수정된 코드가 타입 체크(`tsc` 또는 `mypy`)와 테스트(`pytest` 또는 `vitest`)를 통과하는지 확인한 후에만 Task를 종료한다.
