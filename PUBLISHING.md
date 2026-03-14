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
python3 scripts/export_project_seed.py
```

참고:
- `refresh_snapshot.py` 는 Mac Studio 최신 host QA/Appium 아티팩트와 `automation-run-notes` 사본까지 같이 갱신한다.
- `export_project_seed.py` 는 현재 open issue를 GitHub Projects seed CSV/JSON으로 저장한다.

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
- `.github/workflows/gemini-sanity-check.yml`
  - Actions 탭에서 수동 실행하여 secret/모델 연결을 즉시 검증

참고:
- GitHub CLI 로그인이 없어도, 이 환경에 저장된 macOS 키체인 자격 증명으로 HTTPS push가 가능할 수 있다.
- 필요하면 이후 `gh auth login`을 추가로 해두면 이슈/라벨/프로젝트 자동화가 더 편해진다.
- GitHub Projects를 실제 생성하려면 토큰 scope에 `read:project`, `project`, `read:org` 가 더 필요하다.
- scope 확인과 부트스트랩 안내는 `python3 scripts/bootstrap_github_project.py` 로 볼 수 있다.
