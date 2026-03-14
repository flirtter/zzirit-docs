# GitHub Project State

- project: `ZZIRIT Delivery`
- url: `https://github.com/users/ahg0223/projects/1`
- owner: `ahg0223`
- visibility: `private`
- project number: `1`
- item count: `14`
- field count: `20`

## Custom Fields

- `Work State`
- `Surface`
- `Type`
- `QA Level`
- `Design Gate`
- `Automation`
- `Priority`
- `Spec`
- `Artifacts`
- `Blocker`

## Seed Source

- `snapshots/project-board-seed.csv`
- `snapshots/project-board-seed.json`

## Sync Commands

```bash
cd /Users/user/zzirit-memory-hub
python3 scripts/export_project_seed.py
python3 scripts/sync_github_project.py
```
