# 6. Authentication & Authorization

The http-server example demonstrates a complete auth system with cookie-based authentication and policy-based authorization.

## Authentication

### Overview

```
Client Request → Cookie middleware extracts token → Looks up user → Provides CurrentUser
```

### Step 1: Define `CurrentUser` Context Tag

```typescript
// Domain/User.ts
import { Context } from "effect"

export class CurrentUser extends Context.Tag("Domain/User/CurrentUser")<
  CurrentUser,
  User
>() {}
```

### Step 2: Define the Authentication Middleware

```typescript
// Accounts/Api.ts
import { HttpApiMiddleware, HttpApiSecurity } from "@effect/platform"

export class Authentication extends HttpApiMiddleware.Tag<Authentication>()(
  "Accounts/Api/Authentication",
  {
    provides: CurrentUser,         // What this middleware makes available
    failure: Unauthorized,         // Error type on failure
    security: {
      cookie: HttpApiSecurity.apiKey({
        in: "cookie",              // Read from cookie
        key: "token"               // Cookie name
      })
    }
  }
) {}
```

### Step 3: Implement the Middleware

```typescript
// Accounts/Http.ts
export const AuthenticationLive = Layer.effect(
  Authentication,
  Effect.gen(function*() {
    const userRepo = yield* UsersRepo

    return Authentication.of({
      cookie: (token) =>          // token is Redacted<string>
        userRepo
          .findByAccessToken(accessTokenFromRedacted(token))
          .pipe(
            Effect.flatMap(
              Option.match({
                onNone: () =>
                  new Unauthorized({
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

### Step 4: Apply to Routes

```typescript
// All endpoints in a group:
export class GroupsApi extends HttpApiGroup.make("groups")
  .add(/* endpoints */)
  .middleware(Authentication)
{}

// Selected endpoints only:
export class AccountsApi extends HttpApiGroup.make("accounts")
  .add(/* protected endpoints */)
  .middlewareEndpoints(Authentication)
  // ↓ Endpoints below are public
  .add(HttpApiEndpoint.post("createUser", "/users")/* ... */)
{}
```

### Step 5: Set the Cookie on Login/Registration

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

## Authorization (Policy System)

The example implements a sophisticated policy system that provides compile-time guarantees about authorization checks.

### Core Types

```typescript
// Domain/Policy.ts

// A phantom type that proves authorization was checked
export interface AuthorizedActor<Entity extends string, Action extends string>
  extends User {
  readonly [TypeId]: {
    readonly _Entity: Entity
    readonly _Action: Action
  }
}
```

### Key Functions

#### `policy()` — Define an Authorization Check

```typescript
export const policy = <Entity extends string, Action extends string, E, R>(
  entity: Entity,
  action: Action,
  f: (actor: User) => Effect.Effect<boolean, E, R>
): Effect.Effect<
  AuthorizedActor<Entity, Action>,
  E | Unauthorized,
  R | CurrentUser
> =>
  Effect.flatMap(CurrentUser, (actor) =>
    Effect.flatMap(f(actor), (can) =>
      can
        ? Effect.succeed(authorizedActor(actor))
        : Effect.fail(new Unauthorized({
            actorId: actor.id,
            entity,
            action
          }))
    ))
```

Usage in a policy service:

```typescript
export class AccountsPolicy extends Effect.Service<AccountsPolicy>()(
  "Accounts/Policy",
  {
    effect: Effect.gen(function*() {
      const canUpdate = (toUpdate: UserId) =>
        policy("User", "update", (actor) =>
          Effect.succeed(actor.id === toUpdate)  // Only update yourself
        )

      const canRead = (toRead: UserId) =>
        policy("User", "read", (actor) =>
          Effect.succeed(actor.id === toRead)    // Only read yourself
        )

      return { canUpdate, canRead } as const
    })
  }
) {}
```

#### `policyUse()` — Apply a Policy to an Operation

```typescript
// Wraps an effect so the policy is checked BEFORE execution
export const policyUse = <Actor extends AuthorizedActor<any, any>, E, R>(
  policy: Effect.Effect<Actor, E, R>
) =>
<A, E2, R2>(
  effect: Effect.Effect<A, E2, R2>
): Effect.Effect<A, E | E2, Exclude<R2, Actor> | R> =>
  policy.pipe(Effect.zipRight(effect))
```

Usage:

```typescript
.handle("update", ({ path, payload }) =>
  groups.with(path.id, (group) =>
    pipe(
      groups.update(group, payload),
      policyUse(policy.canUpdate(group))    // ← Check before updating
    )))
```

#### `policyRequire()` — Declare a Policy Requirement

```typescript
// Adds a type-level requirement without runtime enforcement
// Used in service methods to declare what authorization is needed
export const policyRequire = <Entity extends string, Action extends string>(
  _entity: Entity,
  _action: Action
) =>
<A, E, R>(
  effect: Effect.Effect<A, E, R>
): Effect.Effect<A, E, R | AuthorizedActor<Entity, Action>> => effect
```

Usage in services:

```typescript
const createUser = (user: typeof User.jsonCreate.Type) =>
  accountRepo.insert(Account.insert.make({})).pipe(
    // ... business logic ...
    policyRequire("User", "create")  // ← Type says: needs authorized actor for "User:create"
  )
```

#### `policyCompose()` — Compose Multiple Policies

```typescript
// Chain policies: must pass ALL checks
const canCreate = (groupId: GroupId, _person: typeof Person.jsonCreate.Type) =>
  Unauthorized.refail("Person", "create")(
    groups.with(groupId, (group) =>
      pipe(
        groupsPolicy.canUpdate(group),         // Must be able to update the group
        policyCompose(
          policy("Person", "create", (_actor) => Effect.succeed(true))
        )                                       // AND must be able to create persons
      ))
  )
```

#### `withSystemActor` — Bypass Authorization

For system-level operations that don't require a real user:

```typescript
export const withSystemActor = <A, E, R>(
  effect: Effect.Effect<A, E, R>
): Effect.Effect<A, E, Exclude<R, AuthorizedActor<any, any>>> =>
  effect as any

// Usage: creating the first user (no user exists yet)
.handle("createUser", ({ payload }) =>
  accounts.createUser(payload).pipe(withSystemActor))

// Usage: reading your own profile
.handle("getUserMe", () =>
  CurrentUser.pipe(
    Effect.flatMap(accounts.embellishUser),
    withSystemActor
  ))
```

### `Unauthorized` Error

```typescript
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

  // Re-wrap errors from nested policy checks
  static refail(entity: string, action: string) {
    return <A, E, R>(
      effect: Effect.Effect<A, E, R>
    ): Effect.Effect<A, Unauthorized, CurrentUser | R> =>
      Effect.catchIf(
        effect,
        (e) => !Unauthorized.is(e),
        () => Effect.flatMap(
          CurrentUser,
          (actor) => new Unauthorized({ actorId: actor.id, entity, action })
        )
      ) as any
  }
}
```

## How It All Fits Together

```
1. Request arrives with cookie "token=abc123"
2. Authentication middleware:
   - Extracts cookie value
   - Looks up user by access token
   - Provides CurrentUser to the handler
3. Handler calls service method:
   accounts.updateUser(id, payload) ← has policyRequire("User", "update")
4. policyUse(policy.canUpdate(id)) runs:
   - Reads CurrentUser from context
   - Checks: actor.id === toUpdate
   - Returns AuthorizedActor or Unauthorized
5. If authorized: service method runs
6. If unauthorized: 403 response with message
```

## Authorization Flow Diagram

```
Request → Authentication Middleware → CurrentUser provided
                                          ↓
                    Handler: policyUse(policy.canUpdate(group))
                                          ↓
                              policy() reads CurrentUser
                                          ↓
                          f(actor) → boolean check
                             ↓                ↓
                           true             false
                             ↓                ↓
                      AuthorizedActor    Unauthorized(403)
                             ↓
                      Service method executes
```
