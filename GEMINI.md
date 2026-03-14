# GEMINI.md

## Repository Role

This repository is the long-term memory and operations hub for ZZIRIT work.

It is not the primary product codebase. Product implementation happens in:
- `zzirit-v2`
- `zzirit-proxy`

This repository exists to preserve:
- current execution context
- surface specs
- manual design references
- copied automation/review/e2e scripts
- QA evidence and backlog state

## Review Priorities

When reviewing changes in this repository, prioritize:

1. Context integrity
- Do the snapshots still match the current stated operating context?
- Do references and vendored assets remain readable and self-contained?

2. Automation integrity
- Do sync/refresh scripts still produce deterministic outputs?
- Do workflow or issue automation changes break the operating loop?

3. Surface tracking quality
- Do surface specs remain internally consistent with backlog and QA state?
- Are task transitions, follow-up items, and issue materialization still coherent?

4. Signal quality
- Prefer finding broken links, stale paths, misleading state summaries, or missing operational context.
- Do not over-focus on cosmetic wording changes unless they reduce operational clarity.

## Review Rules

- Treat `references/` as vendored context. Large copied files are expected.
- Treat `snapshots/` as generated state. Review whether they are plausible and complete, not whether they are hand-written.
- Flag missing update steps when scripts or references change without corresponding documentation updates.
- Flag issue/backlog drift when task queue, surface specs, and snapshot summaries disagree.
- Avoid suggesting product feature changes unless the memory hub is incorrectly representing them.

## Useful Paths

- `snapshots/current-state.md`
- `snapshots/automation-state.md`
- `snapshots/qa-status.md`
- `snapshots/issue-backlog.md`
- `snapshots/issue-backlog-detailed.md`
- `references/surface-specs/`
- `references/manual-design/`
- `references/automation-scripts/`
- `scripts/sync_context_assets.py`
- `scripts/refresh_snapshot.py`

## Expected Outputs

For pull request review:
- summarize what changed
- identify real operational risks
- point out stale or inconsistent context
- suggest follow-up only when it improves reproducibility or maintainability

For issue triage:
- identify the most relevant surface or automation area
- suggest labels
- point to the most relevant spec/snapshot/reference paths
- note whether the issue is actionable, blocked, or missing context
