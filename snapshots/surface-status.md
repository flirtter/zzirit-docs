# Surface Status

| id | qa_level | automation_status | current_state | next_step |
| --- | --- | --- | --- | --- |
| login | onboarding_appium | partial | implemented | promote dedicated login host QA after spec confirmation |
| onboarding | host_qa | high | implemented | stabilize release-only capture path for post-onboarding expansion states |
| my | host_qa | high | design_matched | Like 카드 실데이터 연결 (API URL 이슈 해결), 프로필 편집 Firestore 반영 |
| likes | host_qa | high | implemented | keep likes release capture in the design gate and extend clean coverage to unlock/preview states |
| meeting | host_qa | high | implemented | final spacing polish and release clean capture |
| chat | host_qa | high | design_matched | Unknown User 이름 표시, 커스텀 크롭 UI 구현, 사진 메시지 다중 이미지 지원 |
| automation | state_machine | high | implemented | promote release clean capture gates and tighten spec-driven follow-up task generation |
| lightning | manual | low | implemented | 디자인 파리티 검수, 실시간 위치 업데이트 주기 개선 |

## Current spec files
- `README`
- `automation`
- `chat`
- `lightning`
- `likes`
- `login`
- `meeting`
- `my`
- `onboarding`
