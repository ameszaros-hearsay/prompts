# 12. Project Architecture

Recommended patterns and conventions for structuring Effect applications, derived from the official templates and examples.

## Project Types

### Basic (Single Package)

```
my-package/
├── src/
│   └── Program.ts
├── test/
│   └── Dummy.test.ts
├── scratchpad/           # Experimental code (optional)
├── package.json
├── tsconfig.json
├── tsconfig.base.json
├── tsconfig.src.json
├── tsconfig.test.json
└── vitest.config.ts
```

### CLI Application

```
my-cli/
├── src/
│   ├── bin.ts            # Entry point (#!/usr/bin/env node)
│   └── Cli.ts            # Command definitions
├── scripts/
│   └── copy-package-json.ts
├── test/
├── package.json
├── tsconfig.json
├── tsup.config.ts        # Bundle config
└── vitest.config.ts
```

### HTTP Server (Feature-Based)

```
my-server/
├── src/
│   ├── main.ts           # Entry point
│   ├── Api.ts            # Top-level API composition
│   ├── Http.ts           # HTTP server wiring
│   ├── Sql.ts            # Database configuration
│   ├── Tracing.ts        # OpenTelemetry setup
│   ├── Uuid.ts           # UUID service
│   ├── Domain/           # Shared domain models
│   │   ├── Account.ts
│   │   ├── User.ts
│   │   ├── Group.ts
│   │   ├── Person.ts
│   │   ├── Email.ts
│   │   ├── AccessToken.ts
│   │   └── Policy.ts
│   ├── Accounts/         # Feature: Accounts
│   │   ├── Api.ts        # API group + middleware
│   │   ├── Http.ts       # Route handlers
│   │   ├── Policy.ts     # Authorization rules
│   │   ├── AccountsRepo.ts
│   │   └── UsersRepo.ts
│   ├── Groups/           # Feature: Groups
│   │   ├── Api.ts
│   │   ├── Http.ts
│   │   ├── Policy.ts
│   │   └── Repo.ts
│   ├── People/           # Feature: People
│   │   ├── Api.ts
│   │   ├── Http.ts
│   │   ├── Policy.ts
│   │   └── Repo.ts
│   ├── lib/              # Shared utilities
│   │   └── Layer.ts
│   └── migrations/       # SQL migrations
│       ├── 00001_create accounts.ts
│       ├── 00002_create groups.ts
│       └── 00003_create people.ts
├── test/
│   └── Accounts.test.ts
├── data/                 # Database files
│   └── db.sqlite
└── package.json
```

### Monorepo

```
my-monorepo/
├── packages/
│   ├── domain/           # Shared types and API definitions
│   │   ├── src/
│   │   │   └── TodosApi.ts
│   │   └── package.json
│   ├── server/           # Server implementation
│   │   ├── src/
│   │   │   ├── Api.ts
│   │   │   ├── TodosRepository.ts
│   │   │   └── server.ts
│   │   └── package.json
│   └── cli/              # CLI client
│       ├── src/
│       │   ├── bin.ts
│       │   ├── Cli.ts
│       │   └── TodosClient.ts
│       └── package.json
├── pnpm-workspace.yaml
├── tsconfig.json
└── vitest.workspace.ts
```

## Feature Module Pattern

Each feature follows a consistent structure:

```
Feature/
├── Api.ts        # HttpApiGroup definition (contract)
├── Http.ts       # Route handlers (implementation)
├── Policy.ts     # Authorization rules
└── Repo.ts       # Data access (repository)
```

Plus a top-level service file:

```
src/
├── Feature.ts    # Effect.Service with business logic
└── Feature/
    └── ...
```

### Example: Groups Feature

| File | Responsibility |
|------|---------------|
| `Groups/Api.ts` | Defines endpoints: `create`, `update` |
| `Groups/Http.ts` | Implements handlers, wires policies |
| `Groups/Policy.ts` | Defines `canCreate`, `canUpdate` |
| `Groups/Repo.ts` | `Model.makeRepository(Group, ...)` |
| `Groups.ts` | Business logic service: `create`, `update`, `findById`, `with` |

## Naming Conventions

| Pattern | Example |
|---------|---------|
| Domain models | `Account`, `User`, `Group`, `Person` |
| Branded IDs | `AccountId`, `UserId`, `GroupId` |
| ID from string | `UserIdFromString`, `GroupIdFromString` |
| Error classes | `UserNotFound`, `GroupNotFound`, `Unauthorized` |
| Services | `Accounts`, `Groups`, `People`, `Uuid` |
| Service tags | `"Accounts"`, `"Groups"`, `"People"` |
| Repositories | `AccountsRepo`, `UsersRepo`, `GroupsRepo` |
| Repo tags | `"Accounts/AccountsRepo"`, `"Groups/Repo"` |
| Policies | `AccountsPolicy`, `GroupsPolicy`, `PeoplePolicy` |
| API groups | `AccountsApi`, `GroupsApi`, `PeopleApi` |
| HTTP layers | `HttpAccountsLive`, `HttpGroupsLive` |
| Infra layers | `SqlLive`, `TracingLive`, `HttpLive` |
| Test layers | `SqlTest`, `Uuid.Test`, `Accounts.Test` |

## TypeScript Configuration Strategy

The repo uses composite TypeScript projects:

```jsonc
// tsconfig.json — root (references only)
{
  "extends": "./tsconfig.base.json",
  "include": [],
  "references": [
    { "path": "tsconfig.src.json" },
    { "path": "tsconfig.test.json" }
  ]
}
```

```jsonc
// tsconfig.src.json
{
  "extends": "./tsconfig.base.json",
  "compilerOptions": {
    "outDir": "build/esm",
    "rootDir": "src"
  },
  "include": ["src"]
}
```

```jsonc
// tsconfig.test.json
{
  "extends": "./tsconfig.base.json",
  "compilerOptions": {
    "noEmit": true,
    "rootDir": "."
  },
  "include": ["test"],
  "references": [{ "path": "tsconfig.src.json" }]
}
```

## Monorepo Configuration

### pnpm Workspace

```yaml
# pnpm-workspace.yaml
packages:
  - packages/*
```

### Cross-Package References

```json
// packages/cli/package.json
{
  "dependencies": {
    "@template/domain": "workspace:^"
  }
}
```

### Vitest Workspace

```typescript
// vitest.workspace.ts
import { defineWorkspace } from "vitest/config"

export default defineWorkspace(["packages/*"])
```

## Importing Conventions

### Within a Package

```typescript
// Relative imports with .js extension (ESM)
import { Account } from "./Domain/Account.js"
import { SqlLive } from "./Sql.js"
import { makeTestLayer } from "./lib/Layer.js"
```

### Cross-Package (Monorepo)

```typescript
// Package name imports
import { TodosApi } from "@template/domain/TodosApi"
import { TodosClient } from "./TodosClient.js"
```

### In Tests (with Alias)

```typescript
// Using vitest alias (configured in vitest.config.ts)
import { Accounts } from "app/Accounts"
import { AccountsRepo } from "app/Accounts/AccountsRepo"
import { Account, AccountId } from "app/Domain/Account"
```

## Build Pipeline

### For Libraries (Basic/Monorepo)

```
Source (TypeScript)
  → ESM build (tsc)
  → Annotate pure calls (babel)
  → CJS build (babel)
  → Pack (build-utils)
```

### For CLI Applications

```
Source (TypeScript)
  → Bundle to single file (tsup)
  → Distribute as bin
```

### For Servers (Development)

```
Source (TypeScript)
  → tsx --watch (dev mode, no build step)
```

## Dev Tooling

| Tool | Purpose |
|------|---------|
| `tsx` | Run TypeScript directly (dev mode) |
| `tsc -b` | Type checking (`pnpm check`) |
| `vitest` | Testing |
| `eslint` | Linting (with `@effect/eslint-plugin`) |
| `dprint` | Code formatting |
| `changesets` | Version management and changelog |
| `@effect/language-service` | IDE integration (TypeScript plugin) |
