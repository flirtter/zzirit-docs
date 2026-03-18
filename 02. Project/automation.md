---
surface: automation
spec_status: draft
qa_level: state_machine
automation_status: high
---

# Automation Surface Contract

## Scope

This is the meta-surface for the autonomous loop itself.

Targets:

- `/Users/user/zzirit-v2/scripts/automation/*`
- `/Users/user/zzirit-v2/scripts/review/*`
- `/Users/user/zzirit-v2/artifacts/automation/*`

## Non-Negotiable Structure

- The loop must keep a persistent task queue, agent state, and next-action note.
- Every batch must emit machine-readable run state.
- Host QA must emit machine-readable results.
- Design references and design-result gating must be available to the queue.
- The loop must recover from stale mobile/Appium sidecars without human intervention whenever possible.

## Required Files

- `/Users/user/zzirit-v2/artifacts/automation/task-queue.json`
- `/Users/user/zzirit-v2/artifacts/automation/agent-state.json`
- `/Users/user/zzirit-v2/artifacts/automation/next-action.md`
- run-level `result.json`
- run-level `design-result.json`
- run-level `focus-host-qa-result.json` when host QA runs

## Current State

- Task queue and agent-state transitions are in place.
- Manual design references are imported and exposed to runs.
- Design results are now machine-readable and affect queue advancement for UI tasks.
- Surface specs are now available as prompt/state context.
- Queue exhaustion now triggers spec-driven follow-up task creation instead of falling back to done surfaces.
- `chat` host QA has been promoted into the same machine-readable result flow as `meeting/my`.

## Known Gaps

- Release clean capture is not yet the default source for every UI gate.
- Some follow-up tasks still need stricter spec/status graduation rules beyond simple `next_step` reuse.
- Some external-provider live checks still require manual confirmation.

## Done Criteria

- The loop can continue through queue tasks without conversational re-approval.
- UI tasks only advance when host QA and design-result conditions are satisfied.
- Surface specs are used as stable context for future autonomous work.
- When a queue is exhausted, the loop seeds the next work set from surface specs without regressing to completed tasks.
