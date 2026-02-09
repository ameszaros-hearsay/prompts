# 8. Observability & Tracing

Effect integrates with OpenTelemetry for distributed tracing, and provides structured logging out of the box.

## Setup

### Install Dependencies

```bash
pnpm add @effect/opentelemetry
pnpm add @opentelemetry/exporter-trace-otlp-http @opentelemetry/sdk-trace-base @opentelemetry/sdk-trace-node
```

### Configure the Tracing Layer

```typescript
// Tracing.ts
import * as NodeSdk from "@effect/opentelemetry/NodeSdk"
import { OTLPTraceExporter } from "@opentelemetry/exporter-trace-otlp-http"
import { BatchSpanProcessor } from "@opentelemetry/sdk-trace-base"
import { Config, Effect, Layer, Redacted } from "effect"

export const TracingLive = Layer.unwrapEffect(
  Effect.gen(function*() {
    // Optional: Honeycomb API key
    const apiKey = yield* Config.option(Config.redacted("HONEYCOMB_API_KEY"))
    const dataset = yield* Config.withDefault(
      Config.string("HONEYCOMB_DATASET"),
      "effect-http-play"
    )

    // No API key — check for generic OTEL endpoint
    if (apiKey._tag === "None") {
      const endpoint = yield* Config.option(
        Config.string("OTEL_EXPORTER_OTLP_ENDPOINT")
      )
      if (endpoint._tag === "None") {
        return Layer.empty  // No tracing configured
      }
      return NodeSdk.layer(() => ({
        resource: { serviceName: dataset },
        spanProcessor: new BatchSpanProcessor(
          new OTLPTraceExporter({ url: `${endpoint.value}/v1/traces` })
        )
      }))
    }

    // Honeycomb configuration
    const headers = {
      "X-Honeycomb-Team": Redacted.value(apiKey.value),
      "X-Honeycomb-Dataset": dataset
    }
    return NodeSdk.layer(() => ({
      resource: { serviceName: dataset },
      spanProcessor: new BatchSpanProcessor(
        new OTLPTraceExporter({
          url: "https://api.honeycomb.io/v1/traces",
          headers
        })
      )
    }))
  })
)
```

### Provide Tracing to Your App

```typescript
// main.ts
HttpLive.pipe(
  Layer.provide(TracingLive),  // ← Add tracing
  Layer.launch,
  NodeRuntime.runMain
)
```

## Adding Spans

### `Effect.withSpan`

Add observability spans to any operation:

```typescript
const createUser = (user: typeof User.jsonCreate.Type) =>
  accountRepo.insert(Account.insert.make({})).pipe(
    // ... business logic ...
    Effect.withSpan("Accounts.createUser", {
      attributes: { user }  // Attach structured data to the span
    })
  )

const findUserById = (id: UserId) =>
  pipe(
    userRepo.findById(id),
    Effect.withSpan("Accounts.findUserById", {
      attributes: { id }
    })
  )
```

### Span Naming Convention

The codebase follows the pattern `ServiceName.methodName`:

```
Accounts.createUser
Accounts.findUserById
Accounts.findUserByAccessToken
Accounts.embellishUser
Groups.create
Groups.update
Groups.findById
Groups.with
People.create
People.findById
People.with
Authentication.cookie
UsersRepo.findByAccessToken
```

### `Effect.annotateCurrentSpan`

Add attributes to the current span dynamically:

```typescript
const createUser = (user: typeof User.jsonCreate.Type) =>
  accountRepo.insert(Account.insert.make({})).pipe(
    Effect.tap((account) =>
      Effect.annotateCurrentSpan("account", account)  // ← Add data to span
    ),
    // ...
    Effect.withSpan("Accounts.createUser", { attributes: { user } })
  )
```

## Built-in Spans

The repository framework automatically creates spans:

- **Repository operations** — `AccountsRepo.insert`, `GroupsRepo.findById`, etc. (from `Model.makeRepository` via `spanPrefix`)
- **HTTP requests** — Logged by `HttpMiddleware.logger`
- **SQL queries** — Traced by `@effect/sql`

## Structured Logging

Effect provides structured logging that works with the tracing system:

```typescript
// Basic logging
yield* Effect.log("Server started")

// Log levels
yield* Effect.logInfo("User created: ", user)
yield* Effect.logError(`Failed to find todo with id: ${id}`)
yield* Effect.logDebug("Processing request")
yield* Effect.logWarning("Rate limit approaching")

// HTTP server logs (via HttpMiddleware.logger)
// Automatically logs: method, path, status, duration
```

### Server Address Logging

```typescript
export const HttpLive = HttpApiBuilder.serve(HttpMiddleware.logger).pipe(
  // ...
  HttpServer.withLogAddress,  // ← Logs the listening address on startup
  // ...
)
```

## Configuration via Environment Variables

| Variable | Purpose |
|----------|---------|
| `HONEYCOMB_API_KEY` | Honeycomb API key (enables Honeycomb export) |
| `HONEYCOMB_DATASET` | Honeycomb dataset name (default: `"effect-http-play"`) |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | Generic OTLP endpoint (fallback if no Honeycomb key) |

### Running with env file

```bash
tsx --env-file=.env --watch src/main.ts
```

### Example `.env`

```bash
# For local Jaeger/Zipkin/etc.
OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4318

# Or for Honeycomb
HONEYCOMB_API_KEY=your-api-key-here
HONEYCOMB_DATASET=my-app
```

## Config Pattern

The tracing setup uses `Layer.unwrapEffect` to dynamically choose the layer based on configuration:

```typescript
export const TracingLive = Layer.unwrapEffect(
  Effect.gen(function*() {
    const apiKey = yield* Config.option(Config.redacted("HONEYCOMB_API_KEY"))

    if (apiKey._tag === "None") {
      return Layer.empty     // ← No tracing, return empty layer
    }

    return NodeSdk.layer(/* ... */)  // ← Return actual tracing layer
  })
)
```

This means tracing is **optional** — the app works fine without any tracing configuration.

## Trace Flow Example

```
HTTP Request: PATCH /users/1
  └─ HttpMiddleware.logger (auto)
       └─ Authentication.cookie
            └─ Accounts.updateUser { id: 1, user: {...} }
                 ├─ UsersRepo.findById (auto from repository)
                 ├─ UsersRepo.update (auto from repository)
                 └─ SQL Transaction (auto from @effect/sql)
```
