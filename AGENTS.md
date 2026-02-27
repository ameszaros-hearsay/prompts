# Repository Guidelines

## Project Structure & Module Organization
This repository is documentation-first and organized around prompts and reusable skills.

- `prompts/`: core prompt docs (for example `architecture.md`, `security-review.md`) plus role-based prompts under `prompts/rpi/`.
- `skills/<skill-name>/`: each skill lives in its own folder with a required `SKILL.md` and optional `references/`, `assets/`, and `scripts/`.
- `README.md`: high-level project purpose.

When adding new content, prefer extending an existing skill folder before creating a new top-level area.
