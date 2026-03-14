#!/usr/bin/env python3

import subprocess
import sys


OWNER = "@me"
TITLE = "ZZIRIT Delivery"


def run(*args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["gh", *args],
        capture_output=True,
        text=True,
    )


def main() -> int:
    check = run("project", "list", "--owner", OWNER)
    if check.returncode != 0:
        sys.stderr.write(check.stderr)
        sys.stderr.write(
            "\nGitHub Project scope가 부족합니다. 다음 scope가 필요합니다:\n"
            "- read:project\n"
            "- project\n"
            "- read:org\n"
            "\n준비되면 다음처럼 다시 실행하세요:\n"
            "gh auth refresh -h github.com -s read:project,project,read:org,read:discussion\n"
        )
        return 1

    print("GitHub Project 접근 가능")
    print("다음 명령으로 프로젝트를 생성할 수 있습니다:")
    print(f'gh project create --owner {OWNER} --title "{TITLE}"')
    print("그 뒤 playbooks/github-projects.md의 필드와 뷰를 순서대로 추가하면 됩니다.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
