This repo contains LLM prompts and agent skills.

## Install Skills

Launch the interactive installer:

```bash
./scripts/install_skills.sh
```

The interactive CLI:

- defaults the target path to `~/.agents/skills`
- lets you paste or edit any target directory path
- refreshes the checkbox selection only after you press Enter in the path field, so typing stays responsive
- matches the skills already linked from this repo in the last refreshed target directory
- shows per-skill status for installed, missing, broken symlink, conflicting symlink, and real file/directory conflicts
- lets you rename the target symlink when the default name is already occupied
- exits with `Ctrl+D` instead of `q`, so `q` can be typed normally into text fields

The installer is safe to re-run. It will:

- create missing skill symlinks
- remove repo-owned skill symlinks for rows you explicitly deselect in the interactive UI
- leave correct repo-owned symlinks unchanged
- refresh broken or conflicting symlinks when you choose that target name
- refuse to overwrite real files or directories unless you choose a different symlink name

To start the interactive installer on a different target directory:

```bash
./scripts/install_skills.sh --target /tmp/test-skills
```

For scriptable bulk install behavior, use non-interactive mode:

```bash
./scripts/install_skills.sh --non-interactive
```

Non-interactive installs still target `~/.agents/skills` by default. To use another location:

```bash
./scripts/install_skills.sh --non-interactive --target /tmp/test-skills
```

To change the default interactive target root with `AGENTS_HOME`:

```bash
AGENTS_HOME=/tmp/test-agents ./scripts/install_skills.sh
```

Show usage:

```bash
./scripts/install_skills.sh --help
```

## RPI Workflow Skills

This repo includes a Research, Planning, and Implementation workflow for feature work. The workflow is artifact-driven and expects feature documents under `./features/{feature-name}/`.

The usual flow is:

1. Create or refine the feature requirements in `PRD.md`.
2. Research the current codebase into `RESEARCH.md`.
3. Turn the PRD and research into `PLAN.md`.
4. Implement one phase at a time, or orchestrate all incomplete phases in order.

### Skills

- `feature-prd-author`: create `./features/{feature-name}/PRD.md` from a rough feature idea.
- `feature-research-investigator`: inspect the current codebase and write `RESEARCH.md` with evidence, confidence, and dirty-state warnings.
- `feature-implementation-planner`: turn `PRD.md` and `RESEARCH.md` into a phased `PLAN.md` with requirement coverage and tests.
- `phase-implementation-executor`: implement one specific phase from `PLAN.md` with test-first execution and `DOD.md` gating.
- `phase-implementation-orchestrator`: execute multiple incomplete phases in order, break phases into slices, enforce review and fix loops, update `DOD.md`, and create one commit per accepted phase.

### When To Use Which

Use `phase-implementation-executor` when you already know the exact phase to build and want a focused implementation pass.

Use `phase-implementation-orchestrator` when you want Codex to drive the full delivery workflow from an existing plan, including sequential phase execution, slice-by-slice review, fix loops, and phase commits.

### Expected Artifacts

The implementation skills assume these files exist:

- `./features/{feature-name}/PRD.md`
- `./features/{feature-name}/RESEARCH.md`
- `./features/{feature-name}/PLAN.md`

`DOD.md` is used as the phase completion tracker during implementation. The executor and orchestrator create or update it as needed.

### Example Usage

Create a PRD:

```text
Use feature-prd-author for feature "bulk-contact-import" from this request: ...
```

Research current behavior:

```text
Use feature-research-investigator for feature "bulk-contact-import".
User hints: importer service, CSV upload UI, and validation pipeline.
```

Create the implementation plan:

```text
Use feature-implementation-planner for feature "bulk-contact-import".
Solution sketch: parse once, validate rows before persistence, and persist in batches.
```

Implement one phase:

```text
Use phase-implementation-executor for feature "bulk-contact-import" and target phase "Phase 2 - Validation Pipeline".
```

Run the full multi-phase delivery:

```text
Use phase-implementation-orchestrator for feature "bulk-contact-import".
Target phases: all incomplete.
Plan path: ./features/bulk-contact-import/PLAN.md
```
