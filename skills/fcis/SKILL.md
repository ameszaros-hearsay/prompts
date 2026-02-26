---
name: fcis
description: Apply the FC-IS (Functional Core, Imperative Shell) architecture with monadic patterns to improve code quality and design clarity. Use when refactoring business logic to pure core functions, separating IO from decisions, modeling failures with Result/Validation/Option, introducing Reader for pure environment data, and representing effects as data (including Free-style programs).
---

# FC-IS Skill

Use this skill to transform use-cases into a Functional Core + Imperative Shell design.

## Process

1. Identify the use-case boundary and split it into:
   - Shell phase 1: load data and parse raw inputs
   - Core: pure decision logic
   - Shell phase 2: interpret effects and execute IO
2. Convert boundary inputs into domain types early.
   - Use `Validation<T, DomainError[]>` when accumulating independent errors.
   - Keep parsing/DTO/transport concerns in the shell.
3. Replace immediate side effects with effect descriptions.
   - Return a `Plan` with `NewState` (or delta) plus `Effects`.
   - For complex sequencing, model effects as a Free-style program and interpret in shell.
4. Compose business rules monadically.
   - Use `Result.Bind` for dependent sequential steps.
   - Use `Validation.Apply` for independent checks.
   - Use `Option` for absence instead of `null`.
5. Separate errors by layer.
   - Represent business failures as `DomainError` in core return types.
   - Handle infrastructure failures in the shell.
6. Verify core purity before finishing.
   - Remove DB/HTTP/file/clock/random/GUID/logging calls from core.
   - Avoid exceptions for expected business outcomes.

## Core Signature Targets

Choose one of these targets:

- `Decide: Input * State * Policy -> Result<Plan, DomainError>`
- `Decide: Input * State -> Reader<Env, Result<Plan, DomainError>>`
- `Decide: Input * State -> Reader<Env, Result<Program<Unit>, DomainError>>`

Keep `Env` as pure data only.

## Artifacts

When asked to produce implementation guidance, provide:

1. Core type signatures
2. Effect ADT (or Free-style effect functor) proposal
3. Shell interpreter responsibilities
4. Refactor steps per use-case
5. Monad-aware code review checklist

For the full playbook, read `references/fcis-playbook.md`.
