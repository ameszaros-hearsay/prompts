# 9. Testing

Effect provides `@effect/vitest` for seamless integration with Vitest, enabling testing of effectful code with proper dependency injection.

## Setup

### Install Dependencies

```bash
pnpm add -D vitest @effect/vitest
```

### Configure Vitest

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
      "app": path.join(__dirname, "src")  // Import from "app/..." in tests
    }
  }
})
```

## Writing Effect Tests

### Basic Structure

```typescript
import { assert, describe, it } from "@effect/vitest"
import { Effect, Layer } from "effect"

describe("MyService", () => {
  // Regular test
  it("should pass", () => {
    expect(true).toBe(true)
  })

  // Effect test
  it.effect("should do something", () =>
    Effect.gen(function*() {
      const result = yield* Effect.succeed(42)
      assert.strictEqual(result, 42)
    })
  )
})
```

### `it.effect` — Running Effects as Tests

`it.effect` automatically runs the Effect and reports failures:

```typescript
it.effect("createUser", () =>
  Effect.gen(function*() {
    const accounts = yield* Accounts
    const user = yield* pipe(
      accounts.createUser({ email: Email.make("test@example.com") }),
      withSystemActor
    )
    assert.strictEqual(user.id, 1)
    assert.strictEqual(user.accountId, 123)
    assert.strictEqual(user.account.id, 123)
  }).pipe(
    Effect.provide(/* test layers */)
  )
)
```

## Providing Test Dependencies

### Pattern: Layer Composition in Tests

Each test provides its own dependency layers:

```typescript
it.effect("createUser", () =>
  Effect.gen(function*() {
    const accounts = yield* Accounts
    const user = yield* pipe(
      accounts.createUser({ email: Email.make("test@example.com") }),
      withSystemActor
    )
    assert.strictEqual(user.id, 1)
  }).pipe(
    Effect.provide(
      Accounts.Test.pipe(
        Layer.provide(
          makeTestLayer(AccountsRepo)({
            insert: (account) =>
              Effect.map(DateTime.now, (now) =>
                new Account({
                  ...account,
                  id: AccountId.make(123),
                  createdAt: now,
                  updatedAt: now
                })
              )
          })
        ),
        Layer.provide(
          makeTestLayer(UsersRepo)({
            insert: (user) =>
              Effect.map(DateTime.now, (now) =>
                new User({
                  ...user,
                  id: UserId.make(1),
                  createdAt: now,
                  updatedAt: now
                })
              )
          })
        )
      )
    )
  ))
```

### Using `.Test` Layers from Services

Services define their own test layers:

```typescript
// In service definition:
export class Accounts extends Effect.Service<Accounts>()("Accounts", {
  effect: Effect.gen(function*() { /* ... */ }),
  dependencies: [SqlLive, AccountsRepo.Default, UsersRepo.Default, Uuid.Default]
}) {
  // Test layer with mocked SQL and UUID
  static Test = this.DefaultWithoutDependencies.pipe(
    Layer.provideMerge(SqlTest),
    Layer.provideMerge(Uuid.Test)
  )
}

// In tests: Accounts.Test gives you the service with mocked infra
// but you still need to provide repo mocks
Effect.provide(
  Accounts.Test.pipe(
    Layer.provide(makeTestLayer(AccountsRepo)({ /* ... */ })),
    Layer.provide(makeTestLayer(UsersRepo)({ /* ... */ }))
  )
)
```

## Test Mocking with `makeTestLayer`

The `makeTestLayer` utility creates a proxy-based mock:

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
        // Unimplemented methods auto-die with a descriptive error
        return (target as any)[prop] = makeUnimplemented(tag.key, prop)
      },
      has: () => true
    })
  )
```

### Key Features:

1. **Partial mocking** — Only implement methods your test actually calls
2. **Auto-die for unimplemented** — If a test accidentally calls an unimplemented method, it dies with a clear message
3. **Type-safe** — Full TypeScript support for the partial implementation

### Usage Examples:

```typescript
// Mock that returns a specific account on insert
makeTestLayer(AccountsRepo)({
  insert: (account) =>
    Effect.map(DateTime.now, (now) =>
      new Account({
        ...account,
        id: AccountId.make(123),
        createdAt: now,
        updatedAt: now
      })
    )
})

// Mock that returns a user on findById
makeTestLayer(UsersRepo)({
  findById: (id: UserId) =>
    Effect.succeed(
      Option.some(
        new User({
          id,
          email: Email.make("test@example.com"),
          accountId: AccountId.make(123),
          createdAt: Effect.runSync(DateTime.now),
          updatedAt: Effect.runSync(DateTime.now),
          accessToken: accessTokenFromRedacted(Redacted.make("test-uuid"))
        })
      )
    )
})

// Mock with findByAccessToken (custom query)
makeTestLayer(UsersRepo)({
  findByAccessToken: (apiKey) =>
    Effect.succeed(
      Option.some(
        new User({
          id: UserId.make(1),
          email: Email.make("test@example.com"),
          accountId: AccountId.make(123),
          createdAt: Effect.runSync(DateTime.now),
          updatedAt: Effect.runSync(DateTime.now),
          accessToken: apiKey
        })
      )
    )
})
```

## SQL Test Mocking

The `SqlTest` layer mocks the database client:

```typescript
import { SqlClient } from "@effect/sql"
import { identity } from "effect"
import { makeTestLayer } from "./lib/Layer.js"

export const SqlTest = makeTestLayer(SqlClient.SqlClient)({
  withTransaction: identity  // No-op: transactions are pass-through in tests
})
```

## Complete Test Example

```typescript
import { assert, describe, it } from "@effect/vitest"
import { Accounts } from "app/Accounts"
import { AccountsRepo } from "app/Accounts/AccountsRepo"
import { UsersRepo } from "app/Accounts/UsersRepo"
import { Account, AccountId } from "app/Domain/Account"
import { Email } from "app/Domain/Email"
import { withSystemActor } from "app/Domain/Policy"
import { User, UserId } from "app/Domain/User"
import { makeTestLayer } from "app/lib/Layer"
import { DateTime, Effect, Layer, Option, pipe, Redacted } from "effect"

describe("Accounts", () => {
  it.effect("createUser", () =>
    Effect.gen(function*() {
      const accounts = yield* Accounts
      const user = yield* pipe(
        accounts.createUser({ email: Email.make("test@example.com") }),
        withSystemActor
      )
      assert.strictEqual(user.id, 1)
      assert.strictEqual(user.accountId, 123)
      assert.strictEqual(user.account.id, 123)
      assert.strictEqual(Redacted.value(user.accessToken), "test-uuid")
    }).pipe(
      Effect.provide(
        Accounts.Test.pipe(
          Layer.provide(
            makeTestLayer(AccountsRepo)({
              insert: (account) =>
                Effect.map(DateTime.now, (now) =>
                  new Account({
                    ...account,
                    id: AccountId.make(123),
                    createdAt: now,
                    updatedAt: now
                  })
                )
            })
          ),
          Layer.provide(
            makeTestLayer(UsersRepo)({
              insert: (user) =>
                Effect.map(DateTime.now, (now) =>
                  new User({
                    ...user,
                    id: UserId.make(1),
                    createdAt: now,
                    updatedAt: now
                  })
                )
            })
          )
        )
      )
    ))

  it.effect("updateUser", () =>
    Effect.gen(function*() {
      const accounts = yield* Accounts
      const userId = UserId.make(1)

      const updatedUser = yield* pipe(
        accounts.updateUser(userId, { email: Email.make("updated@example.com") }),
        withSystemActor
      )

      assert.strictEqual(updatedUser.id, 1)
      assert.strictEqual(updatedUser.email, "updated@example.com")
    }).pipe(
      Effect.provide(
        Accounts.Test.pipe(
          Layer.provide(makeTestLayer(AccountsRepo)({ /* ... */ })),
          Layer.provide(makeTestLayer(UsersRepo)({
            findById: (id) => Effect.succeed(Option.some(/* mock user */)),
            update: (user) => Effect.map(DateTime.now, (now) =>
              new User({ ...user, updatedAt: now, createdAt: now })
            )
          }))
        )
      )
    ))
})
```

## Testing Best Practices

1. **Use `it.effect`** — Always use `it.effect` for testing Effect-based code
2. **Mock at the repository level** — Test services with mocked repos, not mocked SQL
3. **Use `withSystemActor`** — Bypass authorization in unit tests for service logic
4. **Use `makeTestLayer`** — Partial mocking with auto-die for unimplemented methods
5. **Test one service at a time** — Each test focuses on a single service's logic
6. **Provide layers inline** — Each test case provides its own mock configuration
7. **Use branded types in mocks** — e.g., `AccountId.make(123)`, `UserId.make(1)`
8. **Use `DateTime.now`** — For timestamps in mock data
