# 11. CLI Applications

Effect provides `@effect/cli` for building type-safe command-line applications with subcommands, arguments, options, and help generation.

## Setup

```bash
pnpm add @effect/cli @effect/platform @effect/platform-node effect
```

## Basic CLI

```typescript
// src/Cli.ts
import * as Command from "@effect/cli/Command"

const command = Command.make("hello")

export const run = Command.run(command, {
  name: "Hello World",
  version: "0.0.0"
})
```

### Entry Point

```typescript
// src/bin.ts
#!/usr/bin/env node

import * as NodeContext from "@effect/platform-node/NodeContext"
import * as NodeRuntime from "@effect/platform-node/NodeRuntime"
import * as Effect from "effect/Effect"
import { run } from "./Cli.js"

run(process.argv).pipe(
  Effect.provide(NodeContext.layer),
  NodeRuntime.runMain({ disableErrorReporting: true })
)
```

## CLI with Subcommands

```typescript
// src/Cli.ts
import { Args, Command, Options } from "@effect/cli"
import { TodoId } from "@template/domain/TodosApi"
import { TodosClient } from "./TodosClient.js"

// Define arguments
const todoArg = Args.text({ name: "todo" }).pipe(
  Args.withDescription("The message associated with a todo")
)

// Define options with schema validation
const todoId = Options.withSchema(Options.integer("id"), TodoId).pipe(
  Options.withDescription("The identifier of the todo")
)

// Subcommands
const add = Command.make("add", { todo: todoArg }).pipe(
  Command.withDescription("Add a new todo"),
  Command.withHandler(({ todo }) => TodosClient.create(todo))
)

const done = Command.make("done", { id: todoId }).pipe(
  Command.withDescription("Mark a todo as done"),
  Command.withHandler(({ id }) => TodosClient.complete(id))
)

const list = Command.make("list").pipe(
  Command.withDescription("List all todos"),
  Command.withHandler(() => TodosClient.list)
)

const remove = Command.make("remove", { id: todoId }).pipe(
  Command.withDescription("Remove a todo"),
  Command.withHandler(({ id }) => TodosClient.remove(id))
)

// Root command with subcommands
const command = Command.make("todo").pipe(
  Command.withSubcommands([add, done, list, remove])
)

export const cli = Command.run(command, {
  name: "Todo CLI",
  version: "0.0.0"
})
```

### Running the CLI

```typescript
// src/bin.ts
import { NodeContext, NodeHttpClient, NodeRuntime } from "@effect/platform-node"
import { Effect, Layer } from "effect"
import { cli } from "./Cli.js"
import { TodosClient } from "./TodosClient.js"

const MainLive = TodosClient.Default.pipe(
  Layer.provide(NodeHttpClient.layerUndici),
  Layer.merge(NodeContext.layer)
)

cli(process.argv).pipe(
  Effect.provide(MainLive),
  NodeRuntime.runMain
)
```

## CLI Concepts

### Arguments (`Args`)

Positional parameters:

```typescript
import { Args } from "@effect/cli"

const name = Args.text({ name: "name" })
const count = Args.integer({ name: "count" })

// With description
const todo = Args.text({ name: "todo" }).pipe(
  Args.withDescription("The todo message")
)
```

### Options (`Options`)

Named flags and options:

```typescript
import { Options } from "@effect/cli"

const id = Options.integer("id")
const verbose = Options.boolean("verbose")
const name = Options.text("name")

// With schema validation (branded types!)
const todoId = Options.withSchema(Options.integer("id"), TodoId)

// With description
const id = Options.withSchema(Options.integer("id"), TodoId).pipe(
  Options.withDescription("The identifier of the todo")
)
```

### Commands

```typescript
import { Command } from "@effect/cli"

// Simple command
const hello = Command.make("hello")

// Command with args and options
const greet = Command.make("greet", { name: Args.text({ name: "name" }) }).pipe(
  Command.withDescription("Greet someone"),
  Command.withHandler(({ name }) => Effect.log(`Hello, ${name}!`))
)

// Command with subcommands
const app = Command.make("app").pipe(
  Command.withSubcommands([greet, list, add])
)

// Run
export const run = Command.run(app, {
  name: "My App",
  version: "1.0.0"
})
```

## Building for Distribution

Use `tsup` to bundle the CLI to a single file:

```typescript
// tsup.config.ts (from cli template)
import { defineConfig } from "tsup"

export default defineConfig({
  entry: ["src/bin.ts"],
  format: ["cjs"],
  outDir: "dist",
  clean: true,
  bundle: true,
  // ...
})
```

### Package.json for CLI distribution

```json
{
  "name": "@my-org/my-cli",
  "bin": "bin.cjs",
  "main": "bin.cjs",
  "type": "module",
  "scripts": {
    "build": "tsup"
  }
}
```

## Usage Pattern

```bash
# Basic usage
my-cli add "Buy groceries"
my-cli list
my-cli done --id 1
my-cli remove --id 1

# Auto-generated help
my-cli --help
my-cli add --help
```
