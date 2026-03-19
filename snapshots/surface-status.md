# Surface Status

| id | qa_level | automation_status | current_state | next_step |
| --- | --- | --- | --- | --- |
| login | onboarding_appium | partial | implemented | promote dedicated login host QA after spec confirmation |
| onboarding | host_qa | high | implemented | stabilize release-only capture path for post-onboarding expansion states |
| my | host_qa | high | design_matched | 프로필 편집 15필드 재구성 완료, 커스텀 카메라 UI + 사진 크롭 UI 구현 |
| likes | host_qa | high | doing | 블러/볼트 결제 추가됨, 실 서버 like API 연동 + pre-blurred 이미지 최적화 |
| meeting | host_qa | high | implemented | final spacing polish and release clean capture |
| chat | host_qa | high | design_matched | 위치 NaverMapView 프리뷰 수정, Unknown User Firestore 조회, 메시지 정렬 수정 완료. 커스텀 크롭 UI 남음 |
| automation | state_machine | high | implemented | promote release clean capture gates and tighten spec-driven follow-up task generation |
| lightning | manual | low | doing | 프로필 카드 피드 높이 조정 완료, 프로필 상세 + 스크롤 피드 Figma 매칭 진행 중 |

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
