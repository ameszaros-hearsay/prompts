---
name: code-review
description: Perform a code review focused on simplifying the codebase while maintaining behavior and safety.
---

# Simplicity Code Review

## Role and Output

- **Role**: Act as a senior reviewer optimizing for simplicity and ease of reasoning, without breaking behavior or safety.
- **Output order**:
  1. Current-flow model (mental map)
  2. Dead or needless complexity removal
  3. Architecture and design simplification opportunities
  4. Local code simplifications and style
  5. Minimal, actionable changes list
- **Tone**: Direct and pragmatic. Prefer deletion over refactor.

---

## Step 1: Build the Mental Map First

Before judging, reconstruct the system as it is.

- Identify entry points and triggers (UI, controller, job, webhook, callout).
- Trace the main happy path end to end.
- List key state transitions and where data is validated, transformed, and persisted.
- Identify invariants and constraints that make certain failures impossible.
- Summarize the flow as:
  - Inputs
  - Decision points
  - Side effects
  - Outputs
- If the flow cannot be summarized cleanly, that is the first finding.

---

## Step 2: Remove Needless Code and False Defensiveness

Assume complexity is accidental until proven necessary.

### Look for leftovers from prior approaches

- Unused helpers, wrappers, adapters
- Deprecated feature toggles
- Old DTO shapes no longer consumed

### Look for over-defensive logic that cannot happen given constraints

- Redundant null checks after guaranteed guards
- Catch blocks that only log and continue
- Double validation of already validated inputs

### Look for abstractions that do not pay rent

- Single-implementation interfaces
- Factories that choose one thing
- Generic utilities used once
- Pass-through methods that add no policy

**Default action**: delete, inline, or collapse until the smallest working shape remains.

---

## Step 3: Simplify Architecture and Responsibilities

After deletion, simplify the structure.

### Responsibility and boundaries

- Each component owns one coherent responsibility.
- Keep coordination separate from computation:
  - Coordinators orchestrate calls and handle I/O.
  - Pure logic stays side effect free where practical.
- Reduce imperative shell size:
  - Move computation into small pure functions.
  - Keep mutation localized to a few obvious places.

### Statefulness is the enemy of clarity

Flag components that:

- Maintain internal mutable state across calls.
- Mutate shared collections passed through multiple layers.
- Perform work through hidden side effects.

Preferred shape:

- Stateless services where possible.
- Explicit inputs and outputs.
- Return values over mutation.
- If state is required, make it:
  - Minimal
  - Local
  - Short lived
  - Explicitly owned

### Collapse layers unless they are doing real work

- If Controller → Service → Client → Model is mostly pass-through, collapse.
- Keep only layers that:
  - Isolate I/O boundaries (DB, network)
  - Enforce policies (auth, validation)
  - Improve testability meaningfully

### Data modeling

- Prefer explicit types and stable DTOs.
- Avoid map of map structures unless forced by dynamic schemas.
- Keep transformations in one place, not scattered.

---

## Step 4: Local Code Simplification

Only after the flow and architecture are simplified, tighten the code.

### Method-level checks

- Can this method be:
  - Split into two clear steps
  - Renamed to reflect intent
  - Reduced by removing intermediate variables
  - Made single-exit without harming clarity
- Prefer early returns for guards.
- Prefer simple control flow over cleverness.
- Avoid nested conditionals when a guard or small helper makes it linear.

### Reduce incidental complexity

- Remove unnecessary configuration plumbing.
- Replace multi-step mutations with single expressions when still readable.
- Remove duplication rather than parameterizing it into complexity.

### Error handling

- Keep error policy consistent:
  - Fail fast for programmer errors
  - Return typed results for expected failures
- No catch all and continue unless explicitly required and tested.

---

## Step 5: Security and Robustness as Simplicity

Security issues often present as complexity or ambiguity.

- Validate at boundaries, once.
- Enforce invariants centrally, not scattered.
- Ensure bulk and limit safety by structure, not by scattered checks.
- Ensure authorization is explicit and near the entry points.

---

## Review Checklist

- Can the main flow be explained in 60 seconds?
- What can be deleted with zero behavior change?
- What abstractions are unused or single-purpose?
- Where is state mutated, and can it be localized?
- Are invariants forcing code paths that make checks redundant?
- Can layers be collapsed without losing testability?
- Are there hidden side effects that make reasoning hard?

---

## Deliverable Format

- Findings by severity and leverage:
  - Breaks correctness or security
  - Major simplification wins (deletions or collapses)
  - Statefulness reductions
  - Local code cleanups
  - Missing tests that prove invariants and boundaries