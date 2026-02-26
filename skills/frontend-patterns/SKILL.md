---
name: frontend-patterns
description: Frontend architecture and implementation patterns with explicit decision logic for choosing the right approach and avoiding common anti-patterns. Use when designing or reviewing frontend code for state management, component boundaries, side effects, data fetching, mutations, performance, routing, resilience, forms, accessibility, security, testing, and observability.
---

# Frontend Patterns

Use this skill to select patterns intentionally instead of mixing incompatible approaches.

## Workflow

1. Classify the problem first:
- Data ownership and state
- Data synchronization and mutations
- Rendering and UX responsiveness
- Reliability, accessibility, or security

2. Pick patterns from the decision helper in `references/frontend-patterns-playbook.md`.

3. Record tradeoffs explicitly:
- Why this pattern fits
- Why alternatives were rejected
- Exit criteria to revisit later

4. Keep one primary model per concern:
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

1. Chosen pattern(s)
2. Why this is appropriate now
3. When not to use it
4. Minimal implementation sketch
5. Failure modes and safeguards

## References

- Decision playbook and pattern catalog: `references/frontend-patterns-playbook.md`
