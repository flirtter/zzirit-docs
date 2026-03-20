# ZZIRIT Docs

ZZIRIT 프로젝트의 운영/맥락 허브. Obsidian vault + AI 코딩 어시스턴트 하네스.

## 5분 세팅

### 1. 클론

```bash
git clone https://github.com/flirtter/zzirit-docs.git
cd zzirit-docs
```

### 2. Obsidian으로 열기

1. [Obsidian](https://obsidian.md) 설치 (무료)
2. Obsidian 실행 → **Open folder as vault** → `zzirit-docs` 폴더 선택
3. "Trust author" 클릭 → Community plugins 활성화
4. 플러그인 설치 (Settings > Community plugins > Browse):
   - **Kanban** (칸반 보드)
   - **Dataview** (쿼리)
   - **Templater** (템플릿)

### 3. 탐색 시작

Obsidian에서 `Knowledge.md` 열기 — 모든 문서의 진입점.

주요 문서:
| 문서 | 용도 |
|------|------|
| `Knowledge.md` | 전체 탐색 진입점 |
| `snapshots/current-state.md` | 프로젝트 현재 상태 |
| `02. Project/02. Project.md` | surface별 칸반 |
| `references/api-spec.md` | API 명세 (SSOT) |
| `references/retro-index.md` | 회고/교훈 모음 |

## AI 코딩 어시스턴트로 사용

### Claude Code
```bash
cd zzirit-docs
claude   # CLAUDE.md 자동 로드
```

### Gemini CLI
```bash
cd zzirit-docs
gemini   # GEMINI.md 자동 로드
```

## 레포 구조

```
02. Project/        ← surface별 프로젝트 (login, my, likes, meeting, chat, lightning...)
03. Area/           ← 영구 영역 (Database, Design, Agents, Decisions)
01. Journal/        ← 세션 핸드오버, QA 리포트
references/         ← API 명세, 회고, 시드 가이드, 필드 매핑
snapshots/          ← 프로젝트 상태 스냅샷
99. Templates/      ← 노트 템플릿 (Handover, QA Issue 등)
scripts/            ← 자동화 스크립트
```

## 관련 레포

| 레포 | 설명 | 기술 |
|------|------|------|
| [zzirit-rn](https://github.com/flirtter/zzirit-rn) | 모바일 앱 | React Native + Expo |
| [zzirit-api](https://github.com/flirtter/zzirit-api) | API 서버 | Flask + Firestore |
| **zzirit-docs** (이 레포) | 운영/맥락 허브 | Obsidian vault |

## 핵심 규칙

- 이 레포는 **코드가 아니라 문서**. 실제 코드는 zzirit-rn, zzirit-api에 있음
- 새 문서 추가 시 상위 MOC에 링크
- 세션 종료 시 핸드오버 생성 (교훈 섹션 필수)
- 코드 변경 후 `references/retro-index.md`의 리그레션 체크리스트 실행
- 실제 유저 데이터를 시드/더미로 덮어쓰지 않음
