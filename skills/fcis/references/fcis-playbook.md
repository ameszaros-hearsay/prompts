# FC-IS Playbook With Monads

## 1) Target Shape

Keep shell responsible for IO and orchestration. Keep core pure and return a value that fully describes what happens next.

Recommended end state:

- Core returns: `Result<Plan, DomainError>`
- `Plan` contains:
  - `NewState` (or `StateDelta`)
  - `Effects` (closed ADT, or a Free-style program)
- Shell interprets effects and handles infrastructure failure

This gives a pure core, explicit business failure, and composable workflows.

## 2) Core Types to Standardize

### Option for Absence

Use `Option<T>` instead of `null`.

### Result for Expected Failure

Use `Result<T, DomainError>` for business-rule failures. Do not use exceptions for expected outcomes.

### Validation for Error Accumulation

Use `Validation<T, DomainError[]>` when all independent errors should be returned.

### Reader for Pure Environment Data

Use `Reader<Env, A>` to pass policy/config/feature flags without parameter soup. Keep `Env` data-only.

### Effects as Data

Return effect descriptions, not execution.

Two levels:

- Simple: `Plan = { NewState; Effects: Effect[] }`
- Scalable: `Program<A> = Free<EffectF, A>`

Use Free-style modeling when effect ordering/composition becomes complex.

## 3) Refactoring Loop Per Use-Case

### Step 1: Pull IO Out

Split entrypoint into:

- Shell phase 1: load required data
- Core: decide and produce plan
- Shell phase 2: execute plan

Keep DB/HTTP/clock/random/GUID/logs/metrics in shell.

### Step 2: Make Inputs Explicit

- Parse transport formats in shell (JSON/DTO/rows)
- Construct domain values near the boundary with `Validation`
- Pass validated domain values into core

### Step 3: Replace "Do It Now" With "Describe It"

Return effects like:

- `PersistCustomer(CustomerId, CustomerSnapshot)`
- `SendEmail(EmailAddress, TemplateId, Vars)`
- `PublishEvent(DomainEvent)`

Return either:

- `Result<Plan, DomainError>` (effect list), or
- `Result<Program<Unit>, DomainError>` (Free-style)

### Step 4: Compose With Monadic Operators

- `Map`: transform success
- `Bind`: sequence dependent steps
- `Apply` (Validation): combine independent checks and accumulate errors

Rule:

- Use `Bind` for dependencies
- Use `Apply` for independent validations

### Step 5: Long Workflows

If intermediate IO is required:

- Free-style: yield an effect, interpreter performs IO, resume
- Plain plans: split into multiple core decision functions with shell glue

## 4) Exceptions, Async, and Error Separation

Business failures:

- Represent as `DomainError` in `Result`/`Validation`
- Do not throw for expected business conditions

Infrastructure failures:

- Handle in shell (timeouts/network/transient faults)
- Keep infra errors out of core

Async:

- Keep core sync in normal cases
- Keep shell async where IO is async
- If core is async, do not await external IO

## 5) Final Architecture Template

Core signatures:

- `Decide : Input * State * Policy -> Result<Plan, DomainError>`
- `Decide : Input * State -> Reader<Env, Result<Plan, DomainError>>`
- `Decide : Input * State -> Reader<Env, Result<Program<Unit>, DomainError>>`

Shell duties:

- Build `Env` from config
- Load state and required data
- Call `Decide(...).Run(env)`
- Interpret effects
- Persist/publish/send/log/observe/retry

## 6) Monad-Aware Core Review Checklist

The core should not contain:

- DB context/repositories
- HTTP/file IO
- environment variable reads
- logging/metrics/tracing
- `Now/UtcNow`, random, GUID generation
- control-flow exceptions
- `null`-driven control flow
- external state mutation

The core should contain:

- domain constructors returning `Validation`
- decisions returning `Result`
- effects represented as data
- `Map`/`Bind`/`Apply` composition
- explicit small `Env` via `Reader` when needed
