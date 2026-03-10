---
name: frontend-patterns
description: Frontend architecture decision and review skill with explicit decision logic for choosing patterns intentionally and avoiding common anti-patterns. Use when designing or reviewing frontend architecture for state management, component boundaries, side effects, data synchronization, performance, routing, resilience, forms, accessibility, security, testing, and observability.
---

# Frontend Patterns

Use this skill to select patterns intentionally instead of mixing incompatible approaches.

## Workflow

1. Capture context and constraints first:
- Rendering model and delivery constraints
- Routing and navigation model
- Existing state, cache, and styling approaches already in use
- Team conventions, operational constraints, and performance requirements

2. Classify the problem:
- Data ownership and state
- Data synchronization and mutations
- Rendering and UX responsiveness
- Reliability, accessibility, or security

3. Pick patterns from the relevant section in `references/frontend-patterns-playbook.md`.
- State and data ownership: `Data Flow and State`
- Component boundaries: `Component Architecture and Boundaries`
- Async orchestration: `Side Effects and Async Control`
- Server synchronization: `Data Fetching Caching and Server Synchronization`
- Mutations: `Mutation Patterns`
- Performance and rendering: `Loading and Perceived Performance`, `Lists Feeds and Scrolling UX`, `Rendering and Performance Engineering`
- Navigation: `Routing and Navigation UX`
- Reliability: `Error Handling and Resilience`
- Forms: `Forms and Input Heavy UX`
- Design system concerns: `Styling and Design Systems`
- Quality attributes: `Accessibility and UX Correctness`, `Security and Trust Boundaries`, `Testing and Maintainability`, `Observability and Product Feedback Loops`

4. Record tradeoffs explicitly:
- Why this pattern fits
- Why alternatives were rejected
- Constraints and consequences
- Exit criteria to revisit later

5. Keep one primary model per concern:
- One state mental model per app area
- One styling strategy per codebase area
- One caching strategy per data domain

## Fast Starter Set

Default to this baseline when requirements are not unusual:

- Unidirectional data flow with route-level containers
- Server cache with stale-while-revalidate, request dedupe, explicit invalidation
- Optimistic updates for simple toggles with rollback
- Skeleton loading and scroll restoration
- Cursor pagination for feeds and virtualization for large lists
- Retry with backoff, cancellation, and race control
- Error boundaries with domain-specific error UI

## Output Contract For Recommendations

When applying this skill, produce recommendations in this structure:

1. Decision statement
2. Context and constraints
3. Chosen pattern(s)
4. Rejected alternatives
5. Consequences and tradeoffs
6. Failure modes and safeguards
7. Revisit triggers

## References

- Decision playbook and pattern catalog: `references/frontend-patterns-playbook.md`
