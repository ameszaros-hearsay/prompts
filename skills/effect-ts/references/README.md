# Effect TS Developer Documentation

A comprehensive guide to building production applications with [Effect](https://effect.website), based on patterns from the official Effect-TS examples repository.

## 📖 Table of Contents

| # | Guide | Description |
|---|-------|-------------|
| 1 | [Getting Started](./01-getting-started.md) | Project setup, templates, and your first Effect program |
| 2 | [Core Concepts](./02-core-concepts.md) | Effect type, generators, pipe, Option, Schema, and branded types |
| 3 | [Services & Layers](./03-services-and-layers.md) | Dependency injection, service definitions, and layer composition |
| 4 | [HTTP Server & API](./04-http-server-and-api.md) | Building type-safe HTTP APIs with `@effect/platform` |
| 5 | [SQL & Database](./05-sql-and-database.md) | Database access, models, repositories, migrations, and transactions |
| 6 | [Authentication & Authorization](./06-auth-and-policies.md) | Middleware, security, cookie-based auth, and policy-based authorization |
| 7 | [Error Handling](./07-error-handling.md) | Tagged errors, typed error channels, recovery, and defects |
| 8 | [Observability & Tracing](./08-observability-and-tracing.md) | OpenTelemetry integration, spans, and structured logging |
| 9 | [Testing](./09-testing.md) | Testing with `@effect/vitest`, test layers, and mocking services |
| 10 | [HTTP Client](./10-http-client.md) | Type-safe API clients generated from `HttpApi` definitions |
| 11 | [CLI Applications](./11-cli-applications.md) | Building command-line tools with `@effect/cli` |
| 12 | [Project Architecture](./12-project-architecture.md) | Recommended folder structure, monorepo setup, and conventions |
| 13 | [Cheatsheet](./13-cheatsheet.md) | Quick-reference for the most common patterns and APIs |

## 🗂 About This Repository

This documentation is derived from the **official Effect-TS examples repository** which contains:

- **Templates** — Scaffolding for `basic`, `cli`, and `monorepo` projects via `create-effect-app`
- **Examples** — Full working applications (e.g., an HTTP server with auth, SQL, and tracing)

Use [`create-effect-app`](../../packages/create-effect-app/README.md) to bootstrap a new project:

```bash
npx create-effect-app
```

## 🏗 Key Packages Used

| Package | Purpose |
|---------|---------|
| `effect` | Core library — Effect, Schema, Layer, Config, etc. |
| `@effect/platform` | HTTP server/client, file system, CLI platform abstractions |
| `@effect/platform-node` | Node.js-specific platform implementations |
| `@effect/sql` | Database abstraction, models, repositories |
| `@effect/sql-sqlite-node` | SQLite driver for Node.js |
| `@effect/opentelemetry` | OpenTelemetry tracing integration |
| `@effect/cli` | Declarative CLI framework |
| `@effect/vitest` | Vitest integration for Effect-based tests |
| `@effect/experimental` | Experimental features and utilities |
