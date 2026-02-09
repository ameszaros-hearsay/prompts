# 1. Getting Started with Effect TS

## What is Effect?

Effect is a TypeScript library for building type-safe, composable, and resilient applications. It provides a powerful effect system that makes dependency injection, error handling, concurrency, and resource management first-class citizens of your codebase.

## Quick Start with `create-effect-app`

The fastest way to start a new Effect project:

```bash
npx create-effect-app
```

This interactive CLI lets you choose from three templates:

| Template | Use Case |
|----------|----------|
| **basic** | Single package or library |
| **cli** | Command-line application with `@effect/cli` |
| **monorepo** | Multi-package workspace |

## Manual Project Setup

### 1. Initialize a project

```bash
mkdir my-effect-app && cd my-effect-app
pnpm init
```

### 2. Install dependencies

```bash
pnpm add effect
pnpm add -D typescript @types/node tsx vitest @effect/vitest
```

For an HTTP server:

```bash
pnpm add @effect/platform @effect/platform-node
```

For SQL/database:

```bash
pnpm add @effect/sql @effect/sql-sqlite-node
```

### 3. Configure TypeScript

Use the recommended `tsconfig.base.json`:

```json
{
  "compilerOptions": {
    "strict": true,
    "exactOptionalPropertyTypes": true,
    "moduleDetection": "force",
    "composite": true,
    "resolveJsonModule": true,
    "declaration": true,
    "skipLibCheck": true,
    "emitDecoratorMetadata": true,
    "experimentalDecorators": true,
    "moduleResolution": "NodeNext",
    "lib": ["ES2022", "DOM", "DOM.Iterable"],
    "target": "ES2022",
    "module": "NodeNext",
    "sourceMap": true,
    "declarationMap": true,
    "noUnusedLocals": true,
    "noFallthroughCasesInSwitch": true,
    "forceConsistentCasingInFileNames": true,
    "noImplicitAny": true,
    "strictNullChecks": true,
    "incremental": true,
    "plugins": [{ "name": "@effect/language-service" }]
  }
}
```

> **Key:** `strict: true`, `exactOptionalPropertyTypes: true`, and `experimentalDecorators: true` are essential for Effect.

### 4. Configure Vitest

```typescript
// vitest.config.ts
import path from "path"
import { defineConfig } from "vitest/config"

export default defineConfig({
  test: {
    include: ["./test/**/*.test.ts"],
    globals: true
  },
  resolve: {
    alias: {
      "app": path.join(__dirname, "src")
    }
  }
})
```

### 5. Package scripts

```json
{
  "type": "module",
  "scripts": {
    "check": "tsc -b tsconfig.json",
    "dev": "tsx --watch src/main.ts",
    "test": "vitest"
  }
}
```

## Your First Effect Program

```typescript
// src/main.ts
import { NodeRuntime } from "@effect/platform-node"
import { Effect } from "effect"

const program = Effect.gen(function*() {
  yield* Effect.log("Hello, Effect!")
  const result = yield* Effect.succeed(42)
  yield* Effect.log(`The answer is ${result}`)
})

NodeRuntime.runMain(program)
```

Run it:

```bash
npx tsx src/main.ts
```

## Running the HTTP Server Example

The repository includes a full HTTP server example:

```bash
cd examples/http-server
pnpm install
pnpm dev
```

This starts a server on `http://localhost:3000` with:
- User account management (CRUD with authentication)
- Groups and People management
- Swagger UI at `/docs`
- Cookie-based authentication
- SQLite database with automatic migrations
- Optional OpenTelemetry tracing

## Project Structure (Recommended)

```
my-effect-app/
├── src/
│   ├── main.ts              # Entry point
│   ├── Api.ts                # HTTP API definition
│   ├── Http.ts               # HTTP server wiring
│   ├── Sql.ts                # Database configuration
│   ├── Domain/               # Domain models & schemas
│   │   ├── Account.ts
│   │   └── User.ts
│   ├── Accounts/             # Feature module
│   │   ├── Api.ts            # API group definition
│   │   ├── Http.ts           # Route handlers
│   │   ├── Policy.ts         # Authorization policies
│   │   ├── AccountsRepo.ts   # Data access
│   │   └── UsersRepo.ts
│   ├── lib/                  # Shared utilities
│   └── migrations/           # SQL migration files
├── test/
│   └── Accounts.test.ts
├── package.json
├── tsconfig.json
└── vitest.config.ts
```

## Next Steps

- [Core Concepts](./02-core-concepts.md) — Learn the Effect type, generators, and Schema
- [Services & Layers](./03-services-and-layers.md) — Master dependency injection
- [HTTP Server & API](./04-http-server-and-api.md) — Build type-safe APIs
