# 7. Error Handling

Effect has a powerful typed error system that tracks errors at the type level, distinguishing between **expected errors** (recoverable) and **defects** (unexpected failures).

## Error Types in Effect

```
Effect<Success, Error, Requirements>
                 ^^^^^
                 Typed error channel
```

| Category | Description | Example |
|----------|-------------|---------|
| **Expected errors** | Part of the `Error` type parameter, recoverable | `UserNotFound`, `Unauthorized` |
| **Defects** | Not in the type — unexpected, unrecoverable | Database connection lost, null pointer |

## Defining Errors

### Tagged Errors with `Schema.TaggedError`

```typescript
import { HttpApiSchema } from "@effect/platform"
import { Schema } from "effect"

// Basic tagged error
export class PersonNotFound extends Schema.TaggedError<PersonNotFound>()(
  "PersonNotFound",
  { id: PersonId }
) {}

// Tagged error with HTTP status
export class UserNotFound extends Schema.TaggedError<UserNotFound>()(
  "UserNotFound",
  { id: UserId },
  HttpApiSchema.annotations({ status: 404 })  // Maps to 404
) {}

// Tagged error with custom message
export class Unauthorized extends Schema.TaggedError<Unauthorized>()(
  "Unauthorized",
  {
    actorId: UserId,
    entity: Schema.String,
    action: Schema.String
  },
  HttpApiSchema.annotations({ status: 403 })
) {
  get message() {
    return `Actor (${this.actorId}) is not authorized to perform "${this.action}" on "${this.entity}"`
  }
}
```

### Creating Errors

```typescript
// Fail with an error
Effect.fail(new UserNotFound({ id: UserId.make(1) }))

// Fail within a generator
Effect.gen(function*() {
  const user = yield* findUser(id)
  if (Option.isNone(user)) {
    return yield* new UserNotFound({ id })  // yield* auto-fails
  }
})
```

## Error Recovery

### `catchTag` — Recover from a Specific Error

```typescript
const program = client.todos.completeTodo({ path: { id } }).pipe(
  Effect.flatMap((todo) => Effect.logInfo("Completed: ", todo)),
  Effect.catchTag("TodoNotFound", () =>
    Effect.logError(`Failed to find todo with id: ${id}`)
  )
)
// The "TodoNotFound" error is removed from the error channel
```

### `catchAll` — Recover from All Errors

```typescript
const program = riskyOperation.pipe(
  Effect.catchAll((error) => Effect.succeed("fallback"))
)
```

### `catchIf` — Conditional Recovery

```typescript
// From the Unauthorized.refail pattern
Effect.catchIf(
  effect,
  (e) => !Unauthorized.is(e),  // Only catch non-Unauthorized errors
  () => Effect.flatMap(
    CurrentUser,
    (actor) => new Unauthorized({ actorId: actor.id, entity, action })
  )
)
```

### `mapError` — Transform Errors

```typescript
people.findById(path.id).pipe(
  Effect.flatten,
  Effect.mapError(() => new PersonNotFound({ id: path.id }))
)
```

## Converting Errors to Defects

### `Effect.orDie` — Promote Errors to Defects

When you consider an error truly unrecoverable:

```typescript
const createUser = (user: UserInput) =>
  accountRepo.insert(Account.insert.make({})).pipe(
    // ... business logic ...
    sql.withTransaction,
    Effect.orDie  // SqlError becomes a defect (unrecoverable)
  )
```

### `Effect.die` — Create a Defect Directly

```typescript
Effect.die("This should never happen")
Effect.die(new Error("Invariant violated"))
```

### `catchTag` + `die` Pattern

Convert specific errors to defects while keeping others:

```typescript
const result = operation.pipe(
  sql.withTransaction,
  Effect.catchTag("SqlError", (err) => Effect.die(err))  // SQL errors become defects
  // Other errors (like GroupNotFound) remain in the error channel
)
```

## Error Patterns from the Codebase

### Pattern 1: Option → Error

```typescript
// Convert Option.None to a typed error
const findById = (id: GroupId) =>
  repo.findById(id).pipe(
    Effect.flatMap(
      Option.match({
        onNone: () => new GroupNotFound({ id }),
        onSome: Effect.succeed
      })
    )
  )
```

### Pattern 2: "With" Pattern (Transactional Find-or-Fail)

```typescript
const with_ = <A, E, R>(
  id: PersonId,
  f: (person: Person) => Effect.Effect<A, E, R>
): Effect.Effect<A, E | PersonNotFound, R> =>
  pipe(
    repo.findById(id),
    Effect.flatMap(
      Option.match({
        onNone: () => Effect.fail(new PersonNotFound({ id })),
        onSome: Effect.succeed
      })
    ),
    Effect.flatMap(f),                                      // Run callback
    sql.withTransaction,                                    // Wrap in transaction
    Effect.catchTag("SqlError", (e) => Effect.die(e)),     // Defect-ify SQL errors
    Effect.withSpan("People.with", { attributes: { id } })
  )
```

### Pattern 3: Refailing Nested Errors

When composing policies, re-wrap errors with better context:

```typescript
const canCreate = (groupId: GroupId, _person: typeof Person.jsonCreate.Type) =>
  Unauthorized.refail("Person", "create")(   // ← Re-wraps to "Person:create"
    groups.with(groupId, (group) =>
      pipe(
        groupsPolicy.canUpdate(group),        // Might fail with "Group:update"
        policyCompose(
          policy("Person", "create", () => Effect.succeed(true))
        )
      ))
  )
```

### Pattern 4: Error in HTTP API Endpoints

```typescript
HttpApiEndpoint.patch("update", "/:id")
  .addSuccess(Group.json)
  .addError(GroupNotFound)     // ← 404 (from annotation)
  .addError(Unauthorized)      // ← 403 (from annotation, via middleware)
```

Effect automatically handles:
- Serializing errors to JSON responses
- Setting the correct HTTP status code
- Type-checking that handlers only produce declared errors

## Error Hierarchy

```
Effect Error Channel
├── Expected Errors (in type signature)
│   ├── UserNotFound    → 404
│   ├── GroupNotFound   → 404
│   ├── PersonNotFound  → 404
│   └── Unauthorized    → 403
│
└── Defects (NOT in type signature)
    ├── SqlError (promoted via Effect.orDie / catchTag + die)
    └── Unimplemented test methods (via Effect.die)
```

## Best Practices

1. **Use tagged errors** — Always use `Schema.TaggedError` with a unique `_tag` for discriminated unions
2. **Annotate HTTP status** — Add `HttpApiSchema.annotations({ status: N })` for API errors
3. **Declare errors on endpoints** — Use `.addError()` so they appear in the OpenAPI spec
4. **Defect-ify infrastructure errors** — `SqlError`, connection errors → `Effect.orDie`
5. **Keep business errors typed** — `UserNotFound`, `Unauthorized` stay in the error channel
6. **Use the "with" pattern** — For transactional find-then-operate workflows
