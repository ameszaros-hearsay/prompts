# 13. Effect TS Cheatsheet

Quick reference for the most common Effect patterns and APIs.

---

## Effect Basics

```typescript
import { Effect, pipe } from "effect"

// ─── Creating Effects ───────────────────────────────────────
Effect.succeed(42)                          // Effect<42>
Effect.fail(new Error("oops"))              // Effect<never, Error>
Effect.sync(() => Date.now())               // Effect<number>
Effect.promise(() => fetch("/api"))         // Effect<Response>
Effect.die("invariant violated")            // Defect (unrecoverable)
Effect.log("hello")                         // Effect<void>

// ─── Generator Syntax ───────────────────────────────────────
const program = Effect.gen(function*() {
  const a = yield* Effect.succeed(10)
  const b = yield* Effect.succeed(20)
  return a + b
})

// ─── Pipe Syntax ────────────────────────────────────────────
Effect.succeed(5).pipe(
  Effect.map((n) => n * 2),
  Effect.flatMap((n) => Effect.succeed(n + 1)),
  Effect.tap((n) => Effect.log(`value: ${n}`))
)

// ─── Running Effects ────────────────────────────────────────
Effect.runPromise(program)                  // → Promise<A>
Effect.runSync(program)                     // → A (throws if async)
NodeRuntime.runMain(program)                // Node.js entry point
Layer.launch(layer).pipe(NodeRuntime.runMain) // Keep layer alive (servers)
```

## Error Handling

```typescript
// ─── Tagged Errors ──────────────────────────────────────────
class MyError extends Schema.TaggedError<MyError>()(
  "MyError",
  { message: Schema.String },
  HttpApiSchema.annotations({ status: 400 })
) {}

// ─── Failing ────────────────────────────────────────────────
Effect.fail(new MyError({ message: "bad input" }))

// ─── Recovering ─────────────────────────────────────────────
effect.pipe(
  Effect.catchTag("MyError", (e) => Effect.succeed("fallback")),
  Effect.catchAll((e) => Effect.succeed("fallback")),
  Effect.catchIf(isSpecificError, handleIt),
  Effect.mapError((e) => new OtherError({ cause: e })),
  Effect.orDie,                               // errors → defects
)
```

## Option

```typescript
import { Option, Effect } from "effect"

Option.some(42)                             // Option<number>
Option.none()                               // Option<never>
Option.isSome(opt)                          // boolean
Option.isNone(opt)                          // boolean

// Pattern matching
Option.match(opt, {
  onNone: () => "empty",
  onSome: (v) => `got ${v}`
})

// In effects (Option → Error)
Effect.flatMap(repo.findById(id),
  Option.match({
    onNone: () => new NotFound({ id }),
    onSome: Effect.succeed
  })
)

// Flatten Option inside Effect
effect.pipe(Effect.flatten)                 // Effect<Option<A>> → Effect<A, NoSuchElement>
```

## Schema

```typescript
import { Schema } from "effect"

// ─── Primitives ─────────────────────────────────────────────
Schema.String
Schema.Number
Schema.Boolean
Schema.NonEmptyTrimmedString

// ─── Branded Types ──────────────────────────────────────────
const UserId = Schema.Number.pipe(Schema.brand("UserId"))
type UserId = typeof UserId.Type
UserId.make(1)                              // typed as UserId

const Email = Schema.String.pipe(
  Schema.pattern(/^.+@.+\..+$/),
  Schema.brand("Email")
)

// ─── URL Param Conversion ───────────────────────────────────
const UserIdFromString = Schema.NumberFromString.pipe(Schema.compose(UserId))

// ─── Schema Classes ─────────────────────────────────────────
class Todo extends Schema.Class<Todo>("Todo")({
  id: TodoId,
  text: Schema.NonEmptyTrimmedString,
  done: Schema.Boolean
}) {}

// ─── Redacted (Sensitive) ───────────────────────────────────
const Token = Schema.Redacted(Schema.String)
Redacted.make("secret")
Redacted.value(token)                       // extract value
```

## Services & Layers

```typescript
import { Effect, Layer, Context } from "effect"

// ─── Define a Service ───────────────────────────────────────
class MyService extends Effect.Service<MyService>()("MyService", {
  // Simple (no deps):
  succeed: { doThing: Effect.sync(() => "done") },

  // With deps:
  effect: Effect.gen(function*() {
    const dep = yield* OtherService
    return { doThing: () => dep.something() } as const
  }),
  dependencies: [OtherService.Default],

  // Enable static access:
  accessors: true
}) {
  static Test = Layer.succeed(MyService,
    new MyService({ doThing: Effect.succeed("test") })
  )
}

// ─── Use a Service ──────────────────────────────────────────
Effect.gen(function*() {
  const svc = yield* MyService
  yield* svc.doThing
})

// With accessors:
MyService.doThing                           // no need to yield the service

// ─── Context Tag ────────────────────────────────────────────
class CurrentUser extends Context.Tag("CurrentUser")<CurrentUser, User>() {}

// ─── Layer Composition ──────────────────────────────────────
Layer.provide(LayerB, LayerA)               // LayerB depends on LayerA
Layer.merge(LayerA, LayerB)                 // Combine independent layers
Layer.provideMerge(LayerA, LayerB)          // Provide + merge
Layer.effect(Tag, effectThatBuildsIt)       // Layer from effect
Layer.succeed(Tag, value)                   // Layer from value
```

## HTTP API

```typescript
import { HttpApi, HttpApiEndpoint, HttpApiGroup, HttpApiBuilder } from "@effect/platform"

// ─── Define API ─────────────────────────────────────────────
class MyApi extends HttpApiGroup.make("items")
  .add(HttpApiEndpoint.get("list", "/items").addSuccess(Schema.Array(Item)))
  .add(HttpApiEndpoint.post("create", "/items")
    .addSuccess(Item)
    .setPayload(Item.jsonCreate)
  )
  .add(HttpApiEndpoint.get("byId", "/items/:id")
    .setPath(Schema.Struct({ id: ItemIdFromString }))
    .addSuccess(Item)
    .addError(ItemNotFound)
  )
  .add(HttpApiEndpoint.patch("update", "/items/:id")
    .setPath(Schema.Struct({ id: ItemIdFromString }))
    .setPayload(Item.jsonUpdate)
    .addSuccess(Item)
    .addError(ItemNotFound)
  )
  .add(HttpApiEndpoint.del("remove", "/items/:id")
    .setPath(Schema.Struct({ id: ItemIdFromString }))
    .addSuccess(Schema.Void)
    .addError(ItemNotFound)
  )
  .middleware(Authentication)               // Protect all
  .prefix("/api")
  .annotate(OpenApi.Title, "Items")
{}

class Api extends HttpApi.make("api").add(MyApi) {}

// ─── Implement Handlers ─────────────────────────────────────
const HandlersLive = HttpApiBuilder.group(Api, "items", (handlers) =>
  Effect.gen(function*() {
    const svc = yield* ItemService
    return handlers
      .handle("list", () => svc.list)
      .handle("create", ({ payload }) => svc.create(payload))
      .handle("byId", ({ path }) => svc.findById(path.id))
      .handle("update", ({ path, payload }) => svc.update(path.id, payload))
      .handle("remove", ({ path }) => svc.remove(path.id))
  }))

// ─── Wire Server ────────────────────────────────────────────
const ApiLive = HttpApiBuilder.api(Api).pipe(Layer.provide(HandlersLive))

const HttpLive = HttpApiBuilder.serve(HttpMiddleware.logger).pipe(
  Layer.provide(HttpApiSwagger.layer()),
  Layer.provide(HttpApiBuilder.middlewareOpenApi()),
  Layer.provide(HttpApiBuilder.middlewareCors()),
  Layer.provide(ApiLive),
  HttpServer.withLogAddress,
  Layer.provide(NodeHttpServer.layer(createServer, { port: 3000 }))
)
```

## HTTP Client

```typescript
import { HttpApiClient, HttpClient, Cookies } from "@effect/platform"

const cookies = yield* Ref.make(Cookies.empty)
const client = yield* HttpApiClient.make(Api, {
  baseUrl: "http://localhost:3000",
  transformClient: HttpClient.withCookiesRef(cookies)
})

yield* client.items.list()
yield* client.items.create({ payload: { name: "New" } })
yield* client.items.byId({ path: { id: 1 } })
```

## SQL & Models

```typescript
import { Model, SqlClient, SqlSchema } from "@effect/sql"

// ─── Model ──────────────────────────────────────────────────
class Item extends Model.Class<Item>("Item")({
  id: Model.Generated(ItemId),             // DB auto-generates
  name: Schema.NonEmptyTrimmedString,
  ownerId: Model.GeneratedByApp(UserId),   // App generates
  secret: Model.Sensitive(Schema.String),   // Hidden from JSON
  extra: Model.FieldOption(Schema.String),  // Optional → Option
  createdAt: Model.DateTimeInsert,
  updatedAt: Model.DateTimeUpdate
}) {}

// ─── Repository ─────────────────────────────────────────────
class ItemRepo extends Effect.Service<ItemRepo>()("ItemRepo", {
  effect: Model.makeRepository(Item, {
    tableName: "items",
    spanPrefix: "ItemRepo",
    idColumn: "id"
  }),
  dependencies: [SqlLive]
}) {}

// Provides: .insert(), .findById(), .update(), .delete()

// ─── Custom Query ───────────────────────────────────────────
const findByName = SqlSchema.findOne({
  Request: Schema.String,
  Result: Item,
  execute: (name) => sql`SELECT * FROM items WHERE name = ${name}`
})

// ─── Transactions ───────────────────────────────────────────
const sql = yield* SqlClient.SqlClient
myEffect.pipe(sql.withTransaction)

// ─── Migrations ─────────────────────────────────────────────
// src/migrations/00001_create items.ts
export default Effect.gen(function*() {
  const sql = yield* SqlClient.SqlClient
  yield* sql`CREATE TABLE items (...)`
})
```

## Auth Middleware

```typescript
// ─── Define ─────────────────────────────────────────────────
class Auth extends HttpApiMiddleware.Tag<Auth>()("Auth", {
  provides: CurrentUser,
  failure: Unauthorized,
  security: {
    cookie: HttpApiSecurity.apiKey({ in: "cookie", key: "token" })
  }
}) {}

// ─── Implement ──────────────────────────────────────────────
const AuthLive = Layer.effect(Auth, Effect.gen(function*() {
  const repo = yield* UsersRepo
  return Auth.of({
    cookie: (token) => repo.findByToken(token).pipe(/* ... */)
  })
}))

// ─── Set Cookie ─────────────────────────────────────────────
HttpApiBuilder.securitySetCookie(Auth.security.cookie, accessToken)

// ─── Apply to Routes ────────────────────────────────────────
.middleware(Auth)               // all endpoints
.middlewareEndpoints(Auth)      // only above endpoints
```

## Policy Authorization

```typescript
import { policy, policyUse, policyRequire, withSystemActor } from "./Domain/Policy.js"

// ─── Define Policy ──────────────────────────────────────────
const canUpdate = (id: UserId) =>
  policy("User", "update", (actor) => Effect.succeed(actor.id === id))

// ─── Apply to Operation ────────────────────────────────────
pipe(service.update(id, data), policyUse(canUpdate(id)))

// ─── Require (Type-Level Only) ──────────────────────────────
effect.pipe(policyRequire("User", "create"))

// ─── Bypass (System Operations) ─────────────────────────────
accounts.createUser(data).pipe(withSystemActor)
```

## Tracing & Spans

```typescript
// ─── Add Span ───────────────────────────────────────────────
effect.pipe(Effect.withSpan("ServiceName.method", {
  attributes: { id, user }
}))

// ─── Annotate Span ──────────────────────────────────────────
Effect.annotateCurrentSpan("key", value)
```

## Config

```typescript
import { Config } from "effect"

yield* Config.string("DB_URL")                          // required
yield* Config.number("PORT")                            // required number
yield* Config.option(Config.string("API_KEY"))          // optional
yield* Config.withDefault(Config.string("ENV"), "dev")  // with default
yield* Config.redacted("SECRET")                        // Redacted<string>
```

## Testing

```typescript
import { assert, describe, it } from "@effect/vitest"

describe("MyService", () => {
  it.effect("does something", () =>
    Effect.gen(function*() {
      const svc = yield* MyService
      const result = yield* svc.doThing
      assert.strictEqual(result, expected)
    }).pipe(
      Effect.provide(MyService.Test)
    )
  )
})

// Partial mock with auto-die for unimplemented:
makeTestLayer(MyRepo)({
  findById: (id) => Effect.succeed(Option.some(mockItem))
  // other methods die if called
})
```

## Common Patterns

```typescript
// ─── Option → Error ─────────────────────────────────────────
repo.findById(id).pipe(
  Effect.flatMap(Option.match({
    onNone: () => new NotFound({ id }),
    onSome: Effect.succeed
  }))
)

// ─── "With" Pattern (Transactional) ─────────────────────────
const with_ = (id, f) =>
  repo.findById(id).pipe(
    Effect.flatMap(Option.match({
      onNone: () => Effect.fail(new NotFound({ id })),
      onSome: Effect.succeed
    })),
    Effect.flatMap(f),
    sql.withTransaction,
    Effect.catchTag("SqlError", (e) => Effect.die(e))
  )

// ─── Do-Notation (bind) ────────────────────────────────────
Effect.succeed({}).pipe(
  Effect.bind("a", () => getA),
  Effect.bind("b", ({ a }) => getB(a)),
  Effect.map(({ a, b }) => combine(a, b))
)

// ─── Dynamic Layer ──────────────────────────────────────────
Layer.unwrapEffect(Effect.gen(function*() {
  const config = yield* Config.option(Config.string("KEY"))
  if (config._tag === "None") return Layer.empty
  return SomeService.layer(config.value)
}))
```

## Import Patterns

```typescript
// Effect core
import { Effect, Layer, pipe, Option, Schema, Config, Ref, Redacted, Context } from "effect"

// Platform
import { HttpApi, HttpApiBuilder, HttpApiClient, HttpApiEndpoint, HttpApiGroup,
         HttpApiMiddleware, HttpApiSecurity, HttpApiSchema, HttpMiddleware,
         HttpServer, HttpClient, Cookies, OpenApi } from "@effect/platform"
import { NodeHttpServer, NodeRuntime, NodeContext, NodeHttpClient } from "@effect/platform-node"

// SQL
import { SqlClient, SqlSchema } from "@effect/sql"
import { Model } from "@effect/sql"
import { SqliteClient, SqliteMigrator } from "@effect/sql-sqlite-node"

// CLI
import { Args, Command, Options } from "@effect/cli"

// Tracing
import * as NodeSdk from "@effect/opentelemetry/NodeSdk"

// Testing
import { assert, describe, it } from "@effect/vitest"
```
