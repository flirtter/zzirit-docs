# Publishing

현재 상태:
- GitHub private repo 생성 완료
- 원격: `https://github.com/ahg0223/zzirit-memory-hub`
- 로컬 `main` -> `origin/main` 푸시 완료
- 스냅샷 갱신 후 바로 추가 커밋/푸시 가능

권장 절차:

1. 로컬 스냅샷 갱신
```bash
cd /Users/user/zzirit-memory-hub
python3 scripts/sync_context_assets.py
python3 scripts/refresh_snapshot.py
```

참고:
- `refresh_snapshot.py` 는 Mac Studio 최신 host QA/Appium 아티팩트와 `automation-run-notes` 사본까지 같이 갱신한다.

2. 변경 확인
```bash
cd /Users/user/zzirit-memory-hub
git status
```

3. 커밋
```bash
cd /Users/user/zzirit-memory-hub
git add .
git commit -m "docs: refresh memory hub snapshot"
```

4. 푸시
```bash
cd /Users/user/zzirit-memory-hub
git push
```

5. GitHub Actions Gemini review 설정
```text
Repository Settings -> Secrets and variables -> Actions
```

필수 secret:
- `GEMINI_API_KEY`

권장 variables:
- `GEMINI_CLI_VERSION`
- `GEMINI_REVIEW_MODEL`
- `GEMINI_TRIAGE_MODEL`
- `GEMINI_DEBUG`

설정 후 동작:
- `.github/workflows/gemini-pr-review.yml`
  - pull request opened/reopened/synchronize 시 자동 리뷰
- `.github/workflows/gemini-issue-triage.yml`
  - issue opened/reopened/edited 시 자동 triage

참고:
- GitHub CLI 로그인이 없어도, 이 환경에 저장된 macOS 키체인 자격 증명으로 HTTPS push가 가능할 수 있다.
- 필요하면 이후 `gh auth login`을 추가로 해두면 이슈/라벨/프로젝트 자동화가 더 편해진다.
