# 3. Services & Layers (Dependency Injection)

Effect has a powerful built-in dependency injection system centered around **Services** and **Layers**. This eliminates the need for external DI containers.

## Key Concepts

| Concept | Description |
|---------|-------------|
| **Service** | An interface/contract for some functionality |
| **Layer** | A recipe for constructing a service (with its own dependencies) |
| **Tag** | A unique identifier that links a service type to its runtime implementation |

## Defining a Service with `Effect.Service`

The modern way to define a service:

```typescript
import { Effect, Layer } from "effect"

export class Uuid extends Effect.Service<Uuid>()("Uuid", {
  succeed: {
    generate: Effect.sync(() => crypto.randomUUID())
  }
}) {}
```

### Breaking it down:

- `Effect.Service<Uuid>()` — creates both a Tag and a service class
- `"Uuid"` — unique string identifier
- `succeed:` — the service implementation (simple case)

### Using a Service

```typescript
const program = Effect.gen(function*() {
  const uuid = yield* Uuid  // ← yield* on the Tag to get the service
  const id = yield* uuid.generate
  yield* Effect.log(`Generated ID: ${id}`)
})
```

## Service Definition Patterns

### Pattern 1: Simple Service (`succeed`)

For services with no dependencies:

```typescript
export class Uuid extends Effect.Service<Uuid>()("Uuid", {
  succeed: {
    generate: Effect.sync(() => Api.v7())
  }
}) {
  // Test implementation
  static Test = Layer.succeed(
    Uuid,
    new Uuid({
      generate: Effect.succeed("test-uuid")
    })
  )
}
```

### Pattern 2: Service with Dependencies (`effect`)

For services that depend on other services:

```typescript
export class Accounts extends Effect.Service<Accounts>()("Accounts", {
  effect: Effect.gen(function*() {
    // Pull in dependencies
    const sql = yield* SqlClient.SqlClient
    const accountRepo = yield* AccountsRepo
    const userRepo = yield* UsersRepo
    const uuid = yield* Uuid

    // Define operations
    const createUser = (user: typeof User.jsonCreate.Type) =>
      accountRepo.insert(Account.insert.make({})).pipe(
        Effect.bindTo("account"),
        Effect.bind("accessToken", () =>
          uuid.generate.pipe(Effect.map(accessTokenFromString))
        ),
        Effect.bind("user", ({ accessToken, account }) =>
          userRepo.insert(User.insert.make({
            ...user,
            accountId: account.id,
            accessToken
          }))
        ),
        Effect.map(({ account, user }) =>
          new UserWithSensitive({ ...user, account })
        ),
        sql.withTransaction,
        Effect.orDie,
        Effect.withSpan("Accounts.createUser", { attributes: { user } }),
        policyRequire("User", "create")
      )

    const findUserById = (id: UserId) =>
      pipe(
        userRepo.findById(id),
        Effect.withSpan("Accounts.findUserById", { attributes: { id } }),
        policyRequire("User", "read")
      )

    // Return the service interface
    return {
      createUser,
      findUserById,
      // ... more methods
    } as const
  }),

  // Declare dependencies (auto-wired into .Default layer)
  dependencies: [
    SqlLive,
    AccountsRepo.Default,
    UsersRepo.Default,
    Uuid.Default
  ]
}) {}
```

### Pattern 3: Service with Accessors

Add `accessors: true` for static method access without yielding the service:

```typescript
export class TodosClient extends Effect.Service<TodosClient>()(
  "cli/TodosClient",
  {
    accessors: true,  // ← enables static access
    effect: Effect.gen(function*() {
      // ...
      return { create, list, complete, remove } as const
    })
  }
) {}

// Now you can call methods directly on the class:
TodosClient.create("Buy milk")  // instead of: service.create("Buy milk")
TodosClient.list                 // instead of: service.list
```

## Understanding Layers

A **Layer** describes how to build a service from its dependencies.

### Layer Construction

```
Layer<ProvidedService, Error, RequiredDependencies>
```

### Using `.Default`

Every `Effect.Service` automatically gets a `.Default` layer that includes its declared dependencies:

```typescript
export class Groups extends Effect.Service<Groups>()("Groups", {
  effect: Effect.gen(function*() { /* ... */ }),
  dependencies: [SqlLive, GroupsRepo.Default]
}) {}

// Groups.Default is a Layer<Groups> with SqlLive and GroupsRepo already provided
```

### Manual Layer Creation

```typescript
// From a value
const layer = Layer.succeed(Uuid, new Uuid({ generate: Effect.succeed("test") }))

// From an effect
const layer = Layer.effect(Uuid, Effect.gen(function*() {
  return new Uuid({ generate: Effect.sync(() => crypto.randomUUID()) })
}))

// Merging layers
const combined = Layer.merge(LayerA, LayerB)

// Sequential (LayerB depends on LayerA)
const sequential = Layer.provide(LayerB, LayerA)
```

## Layer Composition

### Providing Dependencies

```typescript
// Provide a layer to an effect
const runnable = myProgram.pipe(Effect.provide(Accounts.Default))

// Provide a layer to another layer
const fullLayer = Layer.provide(HttpApiBuilder.api(Api), [
  HttpAccountsLive,
  HttpGroupsLive,
  HttpPeopleLive
])
```

### Real-world HTTP Server Wiring

```typescript
// Http.ts — composing all layers for the server
const ApiLive = Layer.provide(HttpApiBuilder.api(Api), [
  HttpAccountsLive,
  HttpGroupsLive,
  HttpPeopleLive
])

export const HttpLive = HttpApiBuilder.serve(HttpMiddleware.logger).pipe(
  Layer.provide(HttpApiSwagger.layer()),
  Layer.provide(HttpApiBuilder.middlewareOpenApi()),
  Layer.provide(HttpApiBuilder.middlewareCors()),
  Layer.provide(ApiLive),
  HttpServer.withLogAddress,
  Layer.provide(NodeHttpServer.layer(createServer, { port: 3000 }))
)
```

### Application Entry Point

```typescript
// main.ts
import { NodeRuntime } from "@effect/platform-node"
import { Layer } from "effect"
import { HttpLive } from "./Http.js"
import { TracingLive } from "./Tracing.js"

HttpLive.pipe(
  Layer.provide(TracingLive),
  Layer.launch,
  NodeRuntime.runMain
)
```

`Layer.launch` keeps the layer alive (perfect for servers).

## Test Layers

### Pattern: `.Test` on Service Classes

```typescript
export class Uuid extends Effect.Service<Uuid>()("Uuid", {
  succeed: {
    generate: Effect.sync(() => Api.v7())
  }
}) {
  static Test = Layer.succeed(
    Uuid,
    new Uuid({
      generate: Effect.succeed("test-uuid")
    })
  )
}
```

### Pattern: `.Test` with Dependency Override

```typescript
export class Accounts extends Effect.Service<Accounts>()("Accounts", {
  effect: Effect.gen(function*() { /* ... */ }),
  dependencies: [SqlLive, AccountsRepo.Default, UsersRepo.Default, Uuid.Default]
}) {
  static Test = this.DefaultWithoutDependencies.pipe(
    Layer.provideMerge(SqlTest),
    Layer.provideMerge(Uuid.Test)
  )
}
```

Key insight: `this.DefaultWithoutDependencies` gives you the service logic without auto-providing dependencies, so you can substitute test implementations.

### Pattern: Proxy-based Test Layers

For partial mocking — only implement the methods you need:

```typescript
// lib/Layer.ts
export const makeTestLayer = <I, S extends object>(
  tag: Context.Tag<I, S>
) => (service: Partial<S>): Layer.Layer<I> =>
  Layer.succeed(
    tag,
    new Proxy({ ...service } as S, {
      get(target, prop) {
        if (prop in target) return target[prop as keyof S]
        // Auto-creates a "die" effect for unimplemented methods
        return (target as any)[prop] = makeUnimplemented(tag.key, prop)
      },
      has: () => true
    })
  )

// Usage in tests:
const testLayer = makeTestLayer(AccountsRepo)({
  insert: (account) =>
    Effect.map(DateTime.now, (now) =>
      new Account({ ...account, id: AccountId.make(123), createdAt: now, updatedAt: now })
    )
  // Other methods auto-die if called
})
```

## Context Tags (Lower-level API)

For values that don't need a full service class:

```typescript
import { Context } from "effect"

export class CurrentUser extends Context.Tag("Domain/User/CurrentUser")<
  CurrentUser,
  User
>() {}

// Providing a context value
const withUser = Effect.provideService(CurrentUser, someUser)

// Reading a context value
const program = Effect.gen(function*() {
  const user = yield* CurrentUser
})
```

## Dependency Graph Visualization

```
main.ts
  └─ HttpLive
       ├─ NodeHttpServer.layer(port: 3000)
       ├─ HttpApiSwagger.layer()
       ├─ HttpApiBuilder.middlewareOpenApi()
       ├─ HttpApiBuilder.middlewareCors()
       └─ ApiLive
            ├─ HttpAccountsLive
            │    ├─ Accounts.Default
            │    │    ├─ SqlLive (SQLite + Migrations)
            │    │    ├─ AccountsRepo.Default
            │    │    ├─ UsersRepo.Default
            │    │    └─ Uuid.Default
            │    ├─ AccountsPolicy.Default
            │    └─ AuthenticationLive
            │         └─ UsersRepo.Default
            ├─ HttpGroupsLive
            │    ├─ Groups.Default
            │    │    ├─ SqlLive
            │    │    └─ GroupsRepo.Default
            │    └─ GroupsPolicy.Default
            └─ HttpPeopleLive
                 ├─ Groups.Default
                 ├─ People.Default
                 │    ├─ SqlLive
                 │    └─ PeopleRepo.Default
                 └─ PeoplePolicy.Default
```

Effect automatically deduplicates shared dependencies (e.g., `SqlLive` is constructed once).
