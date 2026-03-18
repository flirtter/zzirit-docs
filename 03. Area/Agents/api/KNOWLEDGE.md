# API Agent Knowledge Base

## 🐍 Python & FastAPI Environment

### 1. Circular Import Management
- **Problem**: `meetings.service`와 `chats.service`가 서로를 참조할 때 발생하는 `CircularImportError`.
- **Solution**: 서비스 내부에서 지역 임포트(`from ... import ...`를 함수 내부에 배치)를 사용하여 런타임 의존성을 해결할 것.

### 2. Pydantic v2 Migration
- **Insight**: `Field` 정의 시 `default`와 `default_factory`의 차이를 명확히 인지해야 함. 빈 리스트는 반드시 `default_factory=list`를 사용할 것.

---

## 🔥 Firestore & Data Logic

### 1. Server-side Filtering (Region & Date)
- **Insight**: 클라이언트(모바일)의 부하를 줄이기 위해 지역(`region`)과 날짜(`date`) 필터는 반드시 서버에서 `list` 렌더링 전 처리할 것.
- **Implementation**: 현재 인메모리 레포지토리에서는 리스트 컴프리헨션을 사용 중이나, 향후 Firestore 전환 시 **복합 색인(Composite Index)** 설정이 필수임.

### 2. Geo-Hash Precision
- **Insight**: `geopy`를 사용한 거리 계산 시, 구 형태의 지구 모델을 고려하여 오차 범위를 상시 점검할 것.

---

## 🧪 Testing

### 1. Mocking Auth Context
- **Best Practice**: `get_current_user` 의존성을 `app.dependency_overrides`를 통해 Mock 유저로 교체하여 테스트 일관성을 확보할 것.
