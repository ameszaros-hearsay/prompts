---
name: phase-implementation-orchestrator
description: Execute an existing feature implementation plan end to end by running phases in order, decomposing each phase into reviewable slices, using `phase-implementation-executor` for implementation, enforcing review and fix loops, updating completion tracking, and creating one high-quality git commit per accepted phase. Use when `./features/{feature-name}/PRD.md`, `RESEARCH.md`, and `PLAN.md` already exist and the user wants multiple phases or the full plan delivered safely rather than a single phase.
---

# Phase Implementation Orchestrator

Own sequencing, acceptance gates, and phase finalization for a planned feature. Keep each unit of change small enough to review, but treat the phase as the delivery boundary.

Use this skill to turn an approved `PLAN.md` into completed phases without skipping review, test validation, or repo bookkeeping.

## Required Inputs

- Require `{feature-name}`.
- Accept optional `{target-phases}` when the user wants only a subset. Otherwise start from the first incomplete phase and continue through the remaining phases in `PLAN.md`.
- Require these files in `./features/{feature-name}/`:
  - `PRD.md`
  - `RESEARCH.md`
  - `PLAN.md`
- Require `DOD.md` to exist or create it before execution begins.

## Supporting Skills

- Use `phase-implementation-executor` as the implementation worker for the current phase slice. Pass the active phase name, the exact slice scope, and any acceptance criteria or tests tied to that slice.
- Use `commit-message` when preparing the final phase commit message.
- Let `phase-implementation-executor` pull in `tdd` and `unit-testing` as needed; do not duplicate their instructions here.

## Workflow

### 1. Run Pre-Flight

- Verify the required feature artifacts exist.
- Read `PLAN.md` to identify phases, planned tests, and completion criteria.
- Read `DOD.md` and determine the first incomplete phase.
- Refuse to skip unfinished prerequisite phases unless the user explicitly instructs that the plan has changed.
- Check for a dirty worktree and note it in progress reporting. Do not revert unrelated changes.

### 2. Choose the Execution Window

- If `{target-phases}` is provided, execute only those phases in the order they appear in `PLAN.md`.
- Otherwise execute all incomplete phases in order.
- Treat each phase as the release unit.
- Treat each slice as the review unit.

### 3. Decompose the Current Phase into Slices

- Use slices already present in `PLAN.md` when they exist.
- Otherwise derive slices that:
  - map to a coherent requirement boundary
  - can be verified independently
  - minimize cross-cutting edits
  - keep diffs reviewable
- Do not create a separate testing slice. Tests belong inside each implementation slice.
- Record the slice list before starting implementation.

### 4. Implement One Slice

For the active slice:

1. Invoke `phase-implementation-executor`.
2. Pass:
   - `{feature-name}`
   - current phase
   - exact slice scope
   - relevant requirement IDs
   - slice acceptance criteria
   - slice-specific tests to add or update
3. Require the implementation worker to return:
   - changed files
   - what changed
   - tests run or to run
   - plan deviations
   - residual risks

Keep the implementation worker constrained to the active slice. Do not let it pull future-slice work forward.

### 5. Run the Review Gate

After each slice implementation, run an independent reviewer subagent or perform a clean review pass yourself in code-review mode.

Require this output shape:

- Findings grouped by `High`, `Medium`, and `Low`
- For each finding:
  - severity
  - file or area
  - exact issue
  - recommended fix
  - validation step
- Final line: `High findings remaining: N`

Classify as `High` when the issue is any of:

- correctness bug
- security issue
- data loss risk
- broken build or broken tests
- explicit plan or PRD violation
- missing critical test proving delivered behavior
- unsafe migration or rollout step
- backward compatibility break not acknowledged in the plan

Do not block the phase on `Medium` or `Low` findings unless they clearly imply a hidden correctness problem.

### 6. Run the Fix and Re-Review Loop

If `High findings remaining > 0`:

1. Fix the High findings first.
2. Update or add tests whenever a finding exposes a missing proof.
3. Re-run the relevant tests.
4. Re-run the reviewer.
5. Repeat until `High findings remaining: 0`.

Do not advance to the next slice while any High finding remains open for the current slice.

Address `Medium` and `Low` findings only when:

- the fix is cheap and clearly correct
- the issue would likely be rediscovered in final phase review
- the issue is tightly coupled to the High-finding fix already being made

### 7. Finalize the Phase

After every slice in the phase reaches zero High findings:

1. Run a final review across the whole phase changeset.
2. Re-enter the same fix and re-review loop if the final phase review reports any High findings.
3. Run the phase verification commands from `PLAN.md` and any additional targeted tests needed for changed areas.
4. Update phase completion tracking:
   - mark the relevant `PLAN.md` checklist items complete
   - mark the phase complete in `DOD.md`

Do not mark the phase complete until both slice-level review gates and the final phase review are clear of High findings.

### 8. Commit the Accepted Phase

Create one durable git commit per accepted phase.

Commit requirements:

- Subject line is imperative, phase-scoped, and about 72 characters or less.
- Body includes:
  - phase goal and scope
  - major changes by area
  - tests run and results
  - plan deviations or interpretation notes
  - rollout, migration, or follow-up notes when relevant
- Use `commit-message` to help draft the message when useful.
- Ensure the working tree is clean after the commit, or stop and report what remains uncommitted.

Do not commit while unresolved High findings remain.

## Reporting Contract

After each slice, report:

- slice name
- what changed
- tests run
- review summary
- `High findings remaining: N`
- fix-loop iteration count if any

After each phase, report:

- phase completion status
- tests run
- commit hash
- final commit message text
- any deferred Medium or Low findings worth watching

## Guardrails

- Never silently drop a requirement from `PRD.md` or `PLAN.md`.
- Prefer the least risky interpretation when the plan is ambiguous, but document the interpretation in the phase notes or commit body.
- Stop and ask only when ambiguity likely hides a breaking change, destructive migration, or major behavioral fork not covered by the plan.
- Do not perform unrelated refactors.
- Do not move to the next phase until the current phase is accepted, tracked, and committed.
- If the implementation worker discovers the plan is internally inconsistent, stop orchestration and report the conflict instead of improvising a larger redesign.

## Default Prompt Shape

Use this skill with input shaped like:

```text
feature: {feature-name}
target phases: {optional phase list or "all incomplete"}
plan path: ./features/{feature-name}/PLAN.md
```

If the user only wants one phase implemented, prefer `phase-implementation-executor` directly instead of this orchestrator.
