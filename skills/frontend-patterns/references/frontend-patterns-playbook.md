# Frontend Patterns Playbook

## Table of Contents
- [Decision Helpers](#decision-helpers)
- [Data Flow and State](#data-flow-and-state)
- [Component Architecture and Boundaries](#component-architecture-and-boundaries)
- [Side Effects and Async Control](#side-effects-and-async-control)
- [Data Fetching Caching and Server Synchronization](#data-fetching-caching-and-server-synchronization)
- [Mutation Patterns](#mutation-patterns)
- [Loading and Perceived Performance](#loading-and-perceived-performance)
- [Lists Feeds and Scrolling UX](#lists-feeds-and-scrolling-ux)
- [Rendering and Performance Engineering](#rendering-and-performance-engineering)
- [Routing and Navigation UX](#routing-and-navigation-ux)
- [Error Handling and Resilience](#error-handling-and-resilience)
- [Forms and Input Heavy UX](#forms-and-input-heavy-ux)
- [Styling and Design Systems](#styling-and-design-systems)
- [Accessibility and UX Correctness](#accessibility-and-ux-correctness)
- [Security and Trust Boundaries](#security-and-trust-boundaries)
- [Testing and Maintainability](#testing-and-maintainability)
- [Observability and Product Feedback Loops](#observability-and-product-feedback-loops)

## Decision Helpers

Use these before selecting specific patterns.

### Decision Helper A: State Location
- Keep state local when one component subtree owns it.
- Lift state up when two or more siblings need shared writes.
- Move to shared app state only for cross-route or cross-feature coordination.
- Treat server state as cache and synchronization, not as local UI control state.

Do not globalize state to avoid prop drilling alone. Prefer composition, context boundaries, or compound components first.

### Decision Helper B: Read and Write Paths
- Read-heavy and latency-sensitive UI: favor stale-while-revalidate and prefetch.
- Write-heavy with immediate UX expectations: favor optimistic update with rollback.
- Complex invariants after mutation: refetch authoritative queries instead of fragile local patch chains.

Do not use optimistic updates when conflict rate is high and reconciliation is unclear.

### Decision Helper C: List Strategy
- Small bounded lists: plain rendering.
- Large lists: virtualization/windowing.
- Discovery feeds: infinite scroll with restoration safeguards.
- Task lists and accessibility-sensitive flows: load-more hybrid.

Do not use offset pagination for rapidly changing feeds where inserts/deletes are frequent.

### Decision Helper D: Async Safety
- Cancel requests on parameter change/unmount.
- Tag requests with ids and ignore outdated responses.
- Use retry with capped backoff only for transient failures.

Do not retry validation failures, authorization failures, or deterministic server errors.

## Data Flow and State

- Unidirectional data flow: data down, events up.
Use when component trees are deep and predictability matters.
Avoid when bi-directional sync creates hidden coupling.

- Lift state up to closest common ancestor.
Use when multiple descendants must read and write the same concept.
Avoid when only one child needs it; keep local instead.

- Single source of truth.
Use when duplicated state risks divergence.
Avoid storing mirrored values that can be derived.

- Derived state via selectors/computed/memoized views.
Use for projections and expensive view calculations.
Avoid caching trivial computations that add invalidation complexity.

- Co-locate state by default.
Use for local interaction and encapsulated widgets.
Avoid global stores for ephemeral local concerns.

- Controlled vs uncontrolled components.
Use controlled inputs for validation, formatting, cross-field dependencies.
Use uncontrolled inputs for simple forms or hot paths with performance pressure.
Avoid controlled inputs everywhere by habit.

- Separate local UI state, shared app state, and server state.
Use dedicated mechanisms per type.
Avoid mixing fetched data lifecycle with modal/open/hover state.

- Normalized state for entities.
Use when entities are referenced from many places.
Avoid normalization overhead for tiny one-shot payloads.

- Immutable updates with structural sharing.
Use to keep change detection and memoization reliable.
Avoid in-place mutations in shared state.

- Component-local reactive primitives vs shared stores.
Use one primary reactivity model per app area.
Avoid blending multiple paradigms without strict boundaries.

## Component Architecture and Boundaries

- Presentational vs container separation.
Use presentational components for deterministic UI and container components for data/effects.
Avoid data-fetching side effects inside reusable design-system components.

- Smart boundaries at route/page level.
Use route-level orchestration for data and policies.
Avoid fragmented fetching across deep leaf nodes unless intentionally colocated.

- Composition over configuration.
Use slots/children and composable primitives.
Avoid mega-components with long prop matrices.

- Compound components for related control sets.
Use Tabs, Select, Menu families with shared context.
Avoid prop drilling to synchronize sibling subparts.

- Headless components for behavior reuse.
Use when teams need multiple visual skins with shared behavior.
Avoid coupling behavior packages to one visual theme.

- Feature-based folder structure.
Use domain folders when app scale grows.
Avoid type-only folders that scatter one feature across many directories.

- Public component API discipline.
Use stable props and clear defaults.
Avoid leaking internal state shape in external APIs.

## Side Effects and Async Control

- Isolate effects in hooks/services.
Use components to render from state.
Avoid embedding network orchestration in presentational components.

- Cancellation with AbortController.
Use for request churn and route transitions.
Avoid letting stale responses overwrite fresh state.

- Debounce and throttle intentionally.
Use debounce for text search and async validation.
Use throttle for scroll/resize handlers.
Avoid applying both blindly on the same path.

- Race control policy.
Use latest-wins for search/filter interactions.
Use first-wins for destructive submit actions.
Avoid unspecified race semantics.

- Concurrency limits.
Use bounded parallelism on heavy pages.
Avoid unbounded fan-out that saturates clients and backends.

- Idempotent actions.
Use idempotency keys and dedupe server-side when possible.
Avoid unsafe retries for non-idempotent writes.

## Data Fetching Caching and Server Synchronization

- Stale-while-revalidate default.
Use for most read paths to improve perceived speed.
Avoid for strictly real-time views without freshness indicators.

- Cache keys and invalidation policy.
Use deterministic key composition and explicit mutation invalidation.
Avoid ad hoc keys that prevent reliable cache behavior.

- Request dedupe.
Use shared in-flight promises for identical queries.
Avoid duplicate requests triggered by parallel mounts.

- Pagination strategy.
Use offset pagination for simple static datasets.
Use cursor pagination for feeds and append-only streams.
Avoid offset in volatile ordered data.

- Prefetching on intent.
Use hover, viewport, and anticipated next-route signals.
Avoid broad prefetch that hurts constrained devices.

- Polling vs push.
Use polling for low-complexity periodic freshness.
Use WebSockets/SSE for collaborative or near-live flows.
Avoid push where infra and fallback complexity is unjustified.

- Background refetching.
Use focus/reconnect/interval policies for freshness.
Avoid aggressive intervals that waste battery/network.

## Mutation Patterns

- Optimistic update.
Use for reversible micro-interactions and low-conflict mutations.
Avoid for complex multi-entity invariants unless reconciliation is robust.

- Optimistic navigation.
Use to keep flow momentum with skeleton hydration.
Avoid if destination correctness depends on confirmed write completion.

- Patch vs refetch after mutation.
Use patch for localized deterministic updates.
Use refetch when business rules may affect broad dependent views.
Avoid fragile manual patch graphs.

- Retry with backoff and jitter.
Use for transient transport/service instability.
Avoid infinite retry loops and synchronized retries.

- Outbox pattern.
Use for offline-capable workflows with queued writes.
Avoid without clear pending/error/replay UX states.

## Loading and Perceived Performance

- Skeleton loading.
Use for known layout and medium-to-long waits.
Avoid skeletons that do not resemble final layout.

- Progressive disclosure.
Use to deliver critical path first.
Avoid blocking primary tasks behind secondary panels.

- Incremental rendering.
Use streaming/chunking for large result sets.
Avoid all-or-nothing rendering for data-heavy pages.

- Placeholder vs spinner vs message.
Use spinner for short unknown waits.
Use skeleton for predictable layouts and longer waits.
Use explicit status messages for slow operations.
Avoid indefinite spinners without status.

- Optimistic micro-interactions.
Use for toggles/bookmarks/favorites.
Avoid silent failure; show syncing and rollback states.

## Lists Feeds and Scrolling UX

- Infinite scroll.
Use for discovery browsing.
Avoid where users need footer access and deterministic stopping points.

- Virtualization/windowing.
Use when item count can exceed a few hundred.
Avoid full render of very large collections.

- Load-more hybrid.
Use for accessibility and navigable chunks.
Avoid pure infinite scroll in task-focused contexts.

- Scroll restoration.
Use per-route restoration on back/forward navigation.
Avoid forcing reset to top after drill-down and return.

- IntersectionObserver triggers.
Use for lazy loading and pagination triggers.
Avoid heavy scroll listeners doing repeated layout reads.

## Rendering and Performance Engineering

- Memoization.
Use for expensive computation and stable pure subtrees.
Avoid blanket memoization that adds cognitive overhead.

- Stable references.
Use stable callbacks/objects where referential equality matters.
Avoid recreating dependency objects every render.

- Key stability.
Use persistent ids for list keys.
Avoid array index keys when reorder/insert/delete can occur.

- Code splitting and lazy routes.
Use route-based and heavy-module splits.
Avoid monolithic initial bundles.

- Minimize rerender radius.
Use granular state and component boundaries.
Avoid passing giant mutable objects through many levels.

- Prevent layout thrash.
Use batched DOM reads/writes and transform-based animation.
Avoid interleaving sync measure/mutate loops.

## Routing and Navigation UX

- Route-level data dependencies.
Use explicit per-route requirements.
Avoid hidden deep-child fetch webs.

- Prefetch on intent.
Use hover/touchstart/likely-next navigation hints.
Avoid prefetch storms for low-probability routes.

- Guarded routes.
Use router-boundary auth/role checks with loading and redirect handling.
Avoid late guard failures after partial page render.

- URL as state.
Use query params for shareable filters/sort/pagination/selection.
Avoid encoding purely transient UI details unnecessarily.

- Error routes and fallback UI.
Use dedicated not-found/forbidden/offline/unexpected-error pages.
Avoid generic catch-all errors for distinct scenarios.

## Error Handling and Resilience

- Error boundaries.
Use localized boundaries to isolate failures.
Avoid single top-level boundary as the only protection.

- Domain error modeling.
Use explicit categories: validation, auth, network, server, conflict.
Avoid one generic error shape for all failures.

- Global notifications vs inline errors.
Use toasts for transient non-blocking events.
Use inline messages for actionable field/task errors.
Avoid critical form errors only in toasts.

- Circuit breaker behavior.
Use temporary suppression after repeated backend failure.
Avoid continuous retry storms against known-down dependencies.

- Graceful degradation.
Use fallback behavior to preserve primary user tasks.
Avoid total page failure when optional services fail.

## Forms and Input Heavy UX

- Schema-based validation.
Use shared client/server rules where feasible.
Avoid duplicated inconsistent validation logic.

- Dirty tracking and unsaved-changes guard.
Use for multi-step and long-lived forms.
Avoid silent data loss on navigation.

- Optimistic form submission ergonomics.
Use disabled submit, inline progress, retry path, and input preservation.
Avoid clearing user input on failed submit.

- Field-level async validation.
Use debounced checks with cancellation and explicit pending/success/error states.
Avoid uncanceled stale validation responses.

## Styling and Design Systems

- Design tokens.
Use centralized scales for color, spacing, typography, radii, motion.
Avoid hard-coded one-off style values.

- Component variants.
Use intentional size/tone/intent variants.
Avoid boolean prop explosion.

- Theming strategy.
Use CSS variables or a theme provider with dark/high-contrast support.
Avoid parallel theme mechanisms in the same app section.

- Scoped styling strategy.
Pick one primary approach in a codebase area: CSS Modules, utility-first, or CSS-in-JS.
Avoid fragmented mixed paradigms without boundaries.

## Accessibility and UX Correctness

- Keyboard-first interactions.
Use tabbable controls and visible focus styles.
Avoid pointer-only interactions.

- Focus management.
Use focus trap for modals, restore on close, and focus first error on submit.
Avoid unmanaged focus causing context loss.

- ARIA only when needed.
Use native semantic elements first.
Avoid div-based pseudo-controls when native controls exist.

- Reduced motion.
Use prefers-reduced-motion to tone down non-essential animation.
Avoid forcing motion-heavy transitions.

## Security and Trust Boundaries

- Escape and sanitize.
Use trusted rendering defaults and sanitize rich text.
Avoid injecting unsanitized user HTML.

- CSRF and auth handling.
Use robust token/cookie strategies and refresh handling.
Avoid fragile auth flows that fail silently.

- Permission-based rendering and enforcement.
Use UI checks for UX and server checks for actual security.
Avoid treating hidden UI as authorization.

## Testing and Maintainability

- Testing pyramid.
Use many unit tests for pure logic, integration for key flows, and a small number of E2E critical paths.
Avoid E2E-only coverage.

- Contract tests for APIs.
Use tests that validate response shape and semantics relied on by UI.
Avoid implicit assumptions without verification.

- Visual regression checks.
Use for design system components and critical pages.
Avoid shipping major UI changes without screenshot baselines.

- Story isolation.
Use stories for loading, error, empty, long-content, and edge states.
Avoid documenting only happy paths.

## Observability and Product Feedback Loops

- Frontend logging with context.
Include route, user action, correlation id, release version.
Avoid logging sensitive PII.

- Performance budgets.
Track LCP, INP, CLS and enforce regression alerts or CI checks.
Avoid performance monitoring without thresholds.

- Error reporting.
Capture stack traces and breadcrumbs and group by release.
Avoid unactionable generic error events.

## Baseline Starter Set

Use this baseline when starting a new app or stabilizing an existing one:

- Unidirectional data flow and route-level containers
- Server cache with stale-while-revalidate, dedupe, explicit invalidation
- Optimistic updates for simple toggles with rollback on failure
- Skeleton loading and scroll restoration
- Cursor pagination for feeds and virtualization for large lists
- Retry with backoff, cancellation, and race control
- Error boundaries and domain-specific error UI
