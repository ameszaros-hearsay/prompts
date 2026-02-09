---
name: effect-ts
description: Comprehensive guidance for building, reviewing, and debugging Effect-TS applications across core effects, services and layers, HTTP APIs, SQL models and repositories, auth policies, observability, testing, CLI apps, and project architecture. Use when implementing or refactoring TypeScript code that uses Effect libraries, when selecting Effect patterns, when mapping runtime failures to typed errors, or when scaffolding and organizing Effect-TS projects.
---

# Effect TS Skill

Follow this workflow to handle Effect-TS tasks consistently.

## 1. Classify the request

Identify the primary concern before writing code.

- Setup or bootstrap: use `references/01-getting-started.md`.
- Core effect modeling, schema, option, config, or refs: use `references/02-core-concepts.md`.
- Dependency injection and layer composition: use `references/03-services-and-layers.md`.
- HTTP API/server endpoints and middleware: use `references/04-http-server-and-api.md`.
- SQL models, repositories, migrations, and transactions: use `references/05-sql-and-database.md`.
- Authentication or authorization policies: use `references/06-auth-and-policies.md`.
- Typed error strategy and recovery: use `references/07-error-handling.md`.
- Tracing and structured observability: use `references/08-observability-and-tracing.md`.
- Testing, mock layers, and Effect test patterns: use `references/09-testing.md`.
- Typed HTTP client generation and usage: use `references/10-http-client.md`.
- CLI commands and packaging: use `references/11-cli-applications.md`.
- Project/module structure and monorepo conventions: use `references/12-project-architecture.md`.
- Quick syntax lookup: use `references/13-cheatsheet.md`.

Read only the files relevant to the user request.

## 2. Apply Effect-first implementation rules

- Preserve typed success and error channels; avoid collapsing to untyped exceptions.
- Express dependencies as services and provide them via layers.
- Keep boundary validation explicit with schemas.
- Encode auth and policy checks in middleware or policy helpers, not ad hoc conditionals.
- Use tracing spans and structured logging around external boundaries.
- Build tests with explicit test layers and deterministic mocks.

## 3. Produce implementation-ready output

- Return concrete TypeScript snippets that match Effect idioms.
- Include minimal wiring needed to run in the described architecture.
- State assumptions about runtime, database, and transport boundaries.
- If tradeoffs exist, present one recommended path and one concise alternative.

## Reference index

Use `references/README.md` as the topic map for the full documentation set.
