# 10. HTTP Client

Effect can auto-generate type-safe HTTP clients from your `HttpApi` definition. The client shares the exact same types as the server.

## Setup

```bash
pnpm add @effect/platform @effect/platform-node
```

## Creating a Client

```typescript
import { Cookies, HttpApiClient, HttpClient } from "@effect/platform"
import { NodeHttpClient, NodeRuntime } from "@effect/platform-node"
import { Effect, Ref } from "effect"
import { Api } from "./Api.js"

Effect.gen(function*() {
  // Optional: cookie jar for stateful sessions
  const cookies = yield* Ref.make(Cookies.empty)

  // Create a typed client from the API definition
  const client = yield* HttpApiClient.make(Api, {
    baseUrl: "http://localhost:3000",
    transformClient: HttpClient.withCookiesRef(cookies)
  })

  // Use the client — fully typed!
  const user = yield* client.accounts.createUser({
    payload: {
      email: Email.make("joe@example.com")
    }
  })
  console.log(user) // UserWithSensitive

  // Cookies are auto-managed (auth cookie set by createUser)
  const me = yield* client.accounts.getUserMe()
  console.log(me) // UserWithSensitive
}).pipe(
  Effect.provide(NodeHttpClient.layerUndici),
  NodeRuntime.runMain
)
```

## Client API Shape

The client mirrors the API structure exactly:

```typescript
// API definition:
class Api extends HttpApi.make("api")
  .add(AccountsApi)    // group: "accounts"
  .add(GroupsApi)       // group: "groups"
  .add(PeopleApi)       // group: "people"
{}

// Client usage:
client.accounts.createUser({ payload: { ... } })
client.accounts.getUserMe()
client.accounts.getUser({ path: { id: ... } })
client.accounts.updateUser({ path: { id: ... }, payload: { ... } })

client.groups.create({ payload: { ... } })
client.groups.update({ path: { id: ... }, payload: { ... } })

client.people.create({ path: { groupId: ... }, payload: { ... } })
client.people.findById({ path: { id: ... } })
```

### Parameter Mapping

| Endpoint Config | Client Parameter |
|----------------|-----------------|
| `.setPayload(schema)` | `{ payload: ... }` |
| `.setPath(schema)` | `{ path: ... }` |
| `.setHeaders(schema)` | `{ headers: ... }` |
| `.setUrlParams(schema)` | `{ urlParams: ... }` |

## Cookie Management

For authenticated APIs that use cookies:

```typescript
import { Cookies, HttpClient } from "@effect/platform"
import { Ref } from "effect"

// Create a mutable cookie jar
const cookies = yield* Ref.make(Cookies.empty)

// Attach to the client
const client = yield* HttpApiClient.make(Api, {
  baseUrl: "http://localhost:3000",
  transformClient: HttpClient.withCookiesRef(cookies)
})

// After login/registration, cookies are automatically stored
yield* client.accounts.createUser({
  payload: { email: Email.make("test@example.com") }
})
// The "token" cookie is now in the jar

// Subsequent requests automatically include cookies
yield* client.accounts.getUserMe() // ← Sends cookie header
```

## Client as a Service

For use in larger applications, wrap the client in an `Effect.Service`:

```typescript
export class TodosClient extends Effect.Service<TodosClient>()(
  "cli/TodosClient",
  {
    accessors: true,  // Enable static access: TodosClient.create("text")
    effect: Effect.gen(function*() {
      const client = yield* HttpApiClient.make(TodosApi, {
        baseUrl: "http://localhost:3000"
      })

      function create(text: string) {
        return client.todos.createTodo({ payload: { text } }).pipe(
          Effect.flatMap((todo) => Effect.logInfo("Created todo: ", todo))
        )
      }

      const list = client.todos.getAllTodos().pipe(
        Effect.flatMap((todos) => Effect.logInfo(todos))
      )

      function complete(id: TodoId) {
        return client.todos.completeTodo({ path: { id } }).pipe(
          Effect.flatMap((todo) => Effect.logInfo("Marked todo completed: ", todo)),
          Effect.catchTag("TodoNotFound", () =>
            Effect.logError(`Failed to find todo with id: ${id}`)
          )
        )
      }

      function remove(id: TodoId) {
        return client.todos.removeTodo({ path: { id } }).pipe(
          Effect.flatMap(() => Effect.logInfo(`Deleted todo with id: ${id}`)),
          Effect.catchTag("TodoNotFound", () =>
            Effect.logError(`Failed to find todo with id: ${id}`)
          )
        )
      }

      return { create, list, complete, remove } as const
    })
  }
) {}
```

### Providing the Client Layer

```typescript
const MainLive = TodosClient.Default.pipe(
  Layer.provide(NodeHttpClient.layerUndici),  // HTTP implementation
  Layer.merge(NodeContext.layer)               // Node.js context
)

program.pipe(
  Effect.provide(MainLive),
  NodeRuntime.runMain
)
```

## Error Handling in Clients

Errors declared on endpoints are available as typed errors:

```typescript
// Endpoint declares: .addError(TodoNotFound, { status: 404 })

client.todos.completeTodo({ path: { id } }).pipe(
  Effect.flatMap((todo) => Effect.logInfo("Done: ", todo)),
  Effect.catchTag("TodoNotFound", () =>
    Effect.logError(`Todo not found: ${id}`)
  )
)
```

## Key Benefits

1. **Shared types** — Server and client use the same schemas
2. **Auto-generated** — No manual API client code to maintain
3. **Type-safe errors** — Client errors match server error declarations
4. **Cookie management** — Built-in cookie jar support
5. **OpenAPI compatible** — Works with the auto-generated OpenAPI spec
