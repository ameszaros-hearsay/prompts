# 2. Core Concepts

## The `Effect` Type

The central type in Effect is:

```
Effect<Success, Error, Requirements>
```

| Parameter | Meaning |
|-----------|---------|
| `Success` | The type of the successful result |
| `Error` | The type of expected errors (typed error channel) |
| `Requirements` | Services/dependencies needed to run the effect |

An `Effect` is a **description** of a computation — it doesn't execute until you explicitly run it.

## Generator Syntax (`Effect.gen`)

The primary way to write Effect programs is with generators. This provides `async/await`-like syntax:

```typescript
import { Effect } from "effect"

const program = Effect.gen(function*() {
  const a = yield* Effect.succeed(10)
  const b = yield* Effect.succeed(20)
  yield* Effect.log(`Sum is ${a + b}`)
  return a + b
})
```

`yield*` is equivalent to `await` — it "unwraps" an Effect and gives you its success value. If the effect fails, the generator short-circuits (like a thrown exception in async/await).

### Real-world example from the codebase:

```typescript
// From Accounts.ts — creating a user within a service
const createUser = (user: typeof User.jsonCreate.Type) =>
  accountRepo.insert(Account.insert.make({})).pipe(
    Effect.tap((account) => Effect.annotateCurrentSpan("account", account)),
    Effect.bindTo("account"),
    Effect.bind("accessToken", () =>
      uuid.generate.pipe(Effect.map(accessTokenFromString))
    ),
    Effect.bind("user", ({ accessToken, account }) =>
      userRepo.insert(
        User.insert.make({
          ...user,
          accountId: account.id,
          accessToken
        })
      )
    ),
    Effect.map(({ account, user }) =>
      new UserWithSensitive({ ...user, account })
    ),
    sql.withTransaction,
    Effect.orDie,
    Effect.withSpan("Accounts.createUser", { attributes: { user } })
  )
```

## `pipe` — Composing Operations

`pipe` passes a value through a chain of functions left-to-right:

```typescript
import { pipe, Effect } from "effect"

const result = pipe(
  Effect.succeed(5),
  Effect.map((n) => n * 2),
  Effect.flatMap((n) => Effect.succeed(n + 1))
)
// result: Effect<11, never, never>
```

You can also use the fluent `.pipe()` method on Effect values:

```typescript
const result = Effect.succeed(5).pipe(
  Effect.map((n) => n * 2),
  Effect.flatMap((n) => Effect.succeed(n + 1))
)
```

## Key Effect Constructors

| Constructor | Description |
|-------------|-------------|
| `Effect.succeed(value)` | Wraps a value in a successful Effect |
| `Effect.fail(error)` | Creates a failed Effect |
| `Effect.sync(() => value)` | Lazily creates a value (may throw) |
| `Effect.promise(() => promise)` | Wraps a Promise |
| `Effect.gen(function*() { ... })` | Generator-based Effect creation |
| `Effect.die(defect)` | Creates an unrecoverable failure (defect) |
| `Effect.log(message)` | Logs a message |

## Key Effect Operators

| Operator | Description |
|----------|-------------|
| `Effect.map(f)` | Transform the success value |
| `Effect.flatMap(f)` | Chain effects sequentially |
| `Effect.tap(f)` | Run a side-effect without changing the value |
| `Effect.andThen(f)` | Like `flatMap` but more flexible |
| `Effect.catchTag(tag, handler)` | Recover from a specific tagged error |
| `Effect.catchAll(handler)` | Recover from any error |
| `Effect.orDie` | Convert errors into defects (unrecoverable) |
| `Effect.provide(layer)` | Supply dependencies |
| `Effect.withSpan(name)` | Add observability span |
| `Effect.flatten` | Unwrap nested `Effect<Effect<A>>` |

## `Effect.bind` — Do-notation Style

For sequential computations that build up a context object:

```typescript
const program = Effect.succeed({}).pipe(
  Effect.bind("account", () => accountRepo.insert(Account.insert.make({}))),
  Effect.bind("accessToken", () => uuid.generate.pipe(Effect.map(accessTokenFromString))),
  Effect.bind("user", ({ accessToken, account }) =>
    userRepo.insert(User.insert.make({
      accountId: account.id,
      accessToken
    }))
  ),
  Effect.map(({ account, user }) => new UserWithSensitive({ ...user, account }))
)
```

## `Option` — Representing Optional Values

Effect uses `Option` instead of `null`/`undefined`:

```typescript
import { Option, Effect } from "effect"

// Pattern matching on Option
const handleUser = (user: Option.Option<User>) =>
  Option.match(user, {
    onNone: () => new UserNotFound({ id }),
    onSome: Effect.succeed
  })

// Checking Option
Option.isSome(value) // true if has a value
Option.isNone(value) // true if empty

// Creating Options
Option.some(42)      // Option<number> with value
Option.none()        // empty Option
```

### From the codebase — finding a user:

```typescript
const findUserById = (id: UserId) =>
  userRepo.findById(id).pipe(
    Effect.flatMap(
      Option.match({
        onNone: () => new UserNotFound({ id }),
        onSome: Effect.succeed
      })
    )
  )
```

## `Schema` — Runtime Type Validation

`Schema` provides type-safe encoding/decoding at runtime:

```typescript
import { Schema } from "effect"

// Basic schema with validation
export const Email = Schema.String.pipe(
  Schema.pattern(/^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/),
  Schema.annotations({
    title: "Email",
    description: "An email address"
  }),
  Schema.brand("Email")
)
export type Email = typeof Email.Type

// Usage
const validEmail = Email.make("joe@example.com") // typed as Email (branded)
```

### Schema Classes

```typescript
import { Schema } from "effect"

export class Todo extends Schema.Class<Todo>("Todo")({
  id: TodoId,
  text: Schema.NonEmptyTrimmedString,
  done: Schema.Boolean
}) {}

// Instances:
const todo = new Todo({ id: TodoId.make(1), text: "Buy milk", done: false })
```

### Tagged Errors with Schema

```typescript
export class UserNotFound extends Schema.TaggedError<UserNotFound>()(
  "UserNotFound",
  { id: UserId },
  HttpApiSchema.annotations({ status: 404 })
) {}

// Usage in Effect:
Effect.fail(new UserNotFound({ id: UserId.make(1) }))
```

## Branded Types

Branded types prevent mixing up primitive values:

```typescript
// Define branded types
export const UserId = Schema.Number.pipe(Schema.brand("UserId"))
export type UserId = typeof UserId.Type

export const GroupId = Schema.Number.pipe(Schema.brand("GroupId"))
export type GroupId = typeof GroupId.Type

export const AccountId = Schema.Number.pipe(Schema.brand("AccountId"))
export type AccountId = typeof AccountId.Type

// Now these are NOT interchangeable at the type level:
const userId: UserId = UserId.make(1)
const groupId: GroupId = GroupId.make(1)
// userId === groupId  // ← TypeScript ERROR!
```

### String-to-Branded Conversions (for URL params)

```typescript
export const UserIdFromString = Schema.NumberFromString.pipe(
  Schema.compose(UserId)
)

export const GroupIdFromString = Schema.NumberFromString.pipe(
  Schema.compose(GroupId)
)
```

## `Redacted` — Sensitive Data

For values that should not be logged or serialized accidentally:

```typescript
import { Redacted, Schema } from "effect"

// Define a redacted schema
export const AccessToken = Schema.Redacted(AccessTokenString)
export type AccessToken = typeof AccessToken.Type

// Create a redacted value
const token = Redacted.make("secret-value")

// Extract the value (explicit action)
const raw = Redacted.value(token) // "secret-value"

// toString/JSON.stringify will NOT reveal the value
console.log(token) // "<redacted>"
```

## `Config` — Reading Configuration

```typescript
import { Config, Effect, Redacted } from "effect"

const program = Effect.gen(function*() {
  // Required config
  const port = yield* Config.number("PORT")

  // Optional config
  const apiKey = yield* Config.option(Config.redacted("HONEYCOMB_API_KEY"))

  // Config with default
  const dataset = yield* Config.withDefault(
    Config.string("HONEYCOMB_DATASET"),
    "effect-http-play"
  )
})
```

## `Ref` — Mutable State

`Ref` provides safe mutable state within the Effect system:

```typescript
import { Ref, HashMap, Effect } from "effect"

// Create a ref
const todos = yield* Ref.make(HashMap.empty<TodoId, Todo>())

// Read
const allTodos = yield* Ref.get(todos)

// Update
yield* Ref.update(todos, HashMap.set(todo.id, todo))

// Modify (atomic read + update, returns a value)
const newTodo = yield* Ref.modify(todos, (map) => {
  const todo = new Todo({ id: nextId, text, done: false })
  return [todo, HashMap.set(map, nextId, todo)]
})
```

## Running Effects

| Runner | Context |
|--------|---------|
| `NodeRuntime.runMain(effect)` | Node.js entry point (handles interrupts, logging) |
| `Effect.runPromise(effect)` | Returns a `Promise` |
| `Effect.runSync(effect)` | Synchronous execution (throws if async) |
| `Layer.launch` | Runs a layer and keeps it alive (for servers) |

### Entry point pattern from the example:

```typescript
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
