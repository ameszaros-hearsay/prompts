# 4. HTTP Server & API

Effect provides a fully type-safe HTTP API framework via `@effect/platform`. API definitions are declarative, routes are auto-generated, and you get type-safe clients for free.

## Architecture Overview

```
HttpApi (API definition)
  └── HttpApiGroup (route group)
        └── HttpApiEndpoint (individual route)

HttpApiBuilder (implementation)
  └── .group(Api, "name", handlers)
        └── .handle("endpointName", handler)

HttpApiBuilder.serve() → Layer (running server)
```

## Step 1: Define the API Schema

### Define an Endpoint

```typescript
import { HttpApiEndpoint, HttpApiGroup, HttpApiSecurity, OpenApi } from "@effect/platform"
import { Schema } from "effect"

export class GroupsApi extends HttpApiGroup.make("groups")
  .add(
    HttpApiEndpoint.post("create", "/")
      .addSuccess(Group.json)         // Response type
      .setPayload(Group.jsonCreate)   // Request body type
  )
  .add(
    HttpApiEndpoint.patch("update", "/:id")
      .setPath(Schema.Struct({ id: GroupIdFromString }))  // Path params
      .addSuccess(Group.json)
      .setPayload(Group.jsonUpdate)
      .addError(GroupNotFound)        // Error type → 404
  )
  .middleware(Authentication)         // Protect all routes
  .prefix("/groups")                  // URL prefix
  .annotate(OpenApi.Title, "Groups")
  .annotate(OpenApi.Description, "Manage groups")
{}
```

### Available HTTP Methods

| Method | Constructor |
|--------|-------------|
| GET | `HttpApiEndpoint.get("name", "/path")` |
| POST | `HttpApiEndpoint.post("name", "/path")` |
| PUT | `HttpApiEndpoint.put("name", "/path")` |
| PATCH | `HttpApiEndpoint.patch("name", "/path")` |
| DELETE | `HttpApiEndpoint.del("name", "/path")` |

### Endpoint Configuration

```typescript
HttpApiEndpoint.post("createUser", "/users")
  .addSuccess(UserWithSensitive.json)              // Success response schema
  .setPayload(User.jsonCreate)                     // Request body schema
  .setPath(Schema.Struct({ id: UserIdFromString })) // Path parameters
  .addError(UserNotFound)                          // Typed error (auto → status code)
  .addError(Unauthorized)                          // Multiple errors supported
```

### Compose Groups into an API

```typescript
import { HttpApi, OpenApi } from "@effect/platform"

export class Api extends HttpApi.make("api")
  .add(AccountsApi)
  .add(GroupsApi)
  .add(PeopleApi)
  .annotate(OpenApi.Title, "Groups API")
{}
```

## Step 2: Implement Route Handlers

### Basic Handler Group

```typescript
import { HttpApiBuilder } from "@effect/platform"
import { Effect, Layer } from "effect"

export const HttpGroupsLive = HttpApiBuilder.group(
  Api,          // The API definition
  "groups",     // Must match the group name
  (handlers) =>
    Effect.gen(function*() {
      const groups = yield* Groups        // Inject services
      const policy = yield* GroupsPolicy

      return handlers
        .handle("create", ({ payload }) =>
          CurrentUser.pipe(
            Effect.flatMap((user) =>
              groups.create(user.accountId, payload)
            ),
            policyUse(policy.canCreate(payload))
          ))
        .handle("update", ({ path, payload }) =>
          groups.with(path.id, (group) =>
            pipe(
              groups.update(group, payload),
              policyUse(policy.canUpdate(group))
            )))
    })
).pipe(
  Layer.provide([
    AuthenticationLive,
    Groups.Default,
    GroupsPolicy.Default
  ])
)
```

### Handler Parameters

Each handler receives a typed object based on the endpoint definition:

```typescript
// For: HttpApiEndpoint.patch("update", "/:id").setPath(...).setPayload(...)
.handle("update", ({ path, payload }) => {
  // path.id is typed as GroupId
  // payload is typed as typeof Group.jsonUpdate.Type
})

// For: HttpApiEndpoint.get("getUserMe", "/users/me")
.handle("getUserMe", () => {
  // No parameters — just return an Effect
})

// For: HttpApiEndpoint.post("create", "/groups/:groupId/people").setPath(...)
.handle("create", ({ path, payload }) => {
  // path.groupId is typed as GroupId
  // payload is typed as typeof Person.jsonCreate.Type
})
```

## Step 3: Wire Up the Server

```typescript
import { HttpApiBuilder, HttpApiSwagger, HttpMiddleware, HttpServer } from "@effect/platform"
import { NodeHttpServer } from "@effect/platform-node"
import { Layer } from "effect"
import { createServer } from "http"

// 1. Combine all handler groups
const ApiLive = Layer.provide(HttpApiBuilder.api(Api), [
  HttpAccountsLive,
  HttpGroupsLive,
  HttpPeopleLive
])

// 2. Build the full HTTP server layer
export const HttpLive = HttpApiBuilder.serve(HttpMiddleware.logger).pipe(
  // Swagger UI (available at /docs)
  Layer.provide(HttpApiSwagger.layer()),
  // OpenAPI JSON endpoint
  Layer.provide(HttpApiBuilder.middlewareOpenApi()),
  // CORS support
  Layer.provide(HttpApiBuilder.middlewareCors()),
  // API implementation
  Layer.provide(ApiLive),
  // Log the server address on startup
  HttpServer.withLogAddress,
  // Node.js HTTP server on port 3000
  Layer.provide(NodeHttpServer.layer(createServer, { port: 3000 }))
)
```

### Launch the Server

```typescript
// main.ts
import { NodeRuntime } from "@effect/platform-node"
import { Layer } from "effect"

HttpLive.pipe(
  Layer.provide(TracingLive),  // Optional: add tracing
  Layer.launch,                // Keep alive
  NodeRuntime.runMain          // Handle process signals
)
```

## Built-in Middleware

| Middleware | Purpose |
|-----------|---------|
| `HttpMiddleware.logger` | Log all requests/responses |
| `HttpApiSwagger.layer()` | Serve Swagger UI at `/docs` |
| `HttpApiBuilder.middlewareOpenApi()` | Serve OpenAPI spec as JSON |
| `HttpApiBuilder.middlewareCors()` | Enable CORS headers |

## Custom Middleware (Authentication)

### Define Middleware with a Tag

```typescript
import { HttpApiMiddleware, HttpApiSecurity } from "@effect/platform"
import { Context, Schema } from "effect"

// What the middleware provides to handlers
export class CurrentUser extends Context.Tag("Domain/User/CurrentUser")<
  CurrentUser,
  User
>() {}

// Middleware definition
export class Authentication extends HttpApiMiddleware.Tag<Authentication>()(
  "Accounts/Api/Authentication",
  {
    provides: CurrentUser,        // Makes CurrentUser available
    failure: Unauthorized,        // Error type if auth fails
    security: {
      cookie: HttpApiSecurity.apiKey({
        in: "cookie",
        key: "token"              // Cookie name
      })
    }
  }
) {}
```

### Implement the Middleware

```typescript
export const AuthenticationLive = Layer.effect(
  Authentication,
  Effect.gen(function*() {
    const userRepo = yield* UsersRepo

    return Authentication.of({
      cookie: (token) =>
        userRepo.findByAccessToken(accessTokenFromRedacted(token)).pipe(
          Effect.flatMap(
            Option.match({
              onNone: () => new Unauthorized({
                actorId: UserId.make(-1),
                entity: "User",
                action: "read"
              }),
              onSome: Effect.succeed
            })
          ),
          Effect.withSpan("Authentication.cookie")
        )
    })
  })
).pipe(Layer.provide(UsersRepo.Default))
```

### Apply Middleware

```typescript
// To all endpoints in a group:
export class GroupsApi extends HttpApiGroup.make("groups")
  .add(/* ... endpoints ... */)
  .middleware(Authentication)     // ← all endpoints require auth
{}

// To specific endpoints only:
export class AccountsApi extends HttpApiGroup.make("accounts")
  .add(/* authenticated endpoints */)
  .middlewareEndpoints(Authentication)  // ← only above endpoints
  // Unauthenticated endpoints below:
  .add(
    HttpApiEndpoint.post("createUser", "/users")
      .addSuccess(UserWithSensitive.json)
      .setPayload(User.jsonCreate)
  )
{}
```

### Setting Cookies in Handlers

```typescript
.handle("createUser", ({ payload }) =>
  accounts.createUser(payload).pipe(
    withSystemActor,
    Effect.tap((user) =>
      HttpApiBuilder.securitySetCookie(
        Authentication.security.cookie,
        user.accessToken
      )
    )
  ))
```

## OpenAPI Annotations

```typescript
// On an API
HttpApi.make("api")
  .annotate(OpenApi.Title, "My API")

// On a group
HttpApiGroup.make("accounts")
  .annotate(OpenApi.Title, "Accounts")
  .annotate(OpenApi.Description, "Manage user accounts")

// On a Schema
Schema.String.pipe(
  Schema.annotations({
    title: "Email",
    description: "An email address"
  })
)
```

## Error → HTTP Status Mapping

```typescript
// Annotate errors with HTTP status codes
export class UserNotFound extends Schema.TaggedError<UserNotFound>()(
  "UserNotFound",
  { id: UserId },
  HttpApiSchema.annotations({ status: 404 })
) {}

export class Unauthorized extends Schema.TaggedError<Unauthorized>()(
  "Unauthorized",
  { actorId: UserId, entity: Schema.String, action: Schema.String },
  HttpApiSchema.annotations({ status: 403 })
) {}
```
