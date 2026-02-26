You are a senior software architect and codebase analyst. Your task is to auto-discover the architecture of the repository at, and produce an architecture diagram (in Mermaid) that lets a reviewer spot architectural issues at a glance.

Goal
- Show how the code is structured: layers and/or vertical slices (feature modules), boundaries, and dependency directions.
- Show what calls what: entrypoints -> application/core -> infrastructure.
- Show IO: user actions, UI/API handlers, CLI, jobs, messaging.
- Show persistence: DB, repositories/DAOs, caches, queues, file storage.
- Make architectural issues visually obvious.

Non-goals
- Do not document every class or file. Prefer module/package level structure.
- Do not guess. If something is uncertain, mark it as "unknown" and draw a dashed edge.

How to analyze (auto-discovery)
1) Inventory and classify
- Read the repo tree and identify top-level modules/packages/services (monorepo packages, apps, libs).
- Detect language(s) and framework(s) from build files and conventions (package managers, workspace config, Docker, IaC).
- Identify deployable units (services, functions, apps) vs libraries.

2) Find entrypoints and user actions
- Locate inbound entrypoints: HTTP routes/controllers/handlers, UI event handlers, CLI commands, message consumers, schedulers/cron/jobs.
- Summarize the main inbound flows (at least 3 representative flows if applicable).

3) Infer boundaries and architectural style
- Detect whether the code is primarily:
  - Layered (presentation -> application -> domain -> infrastructure),
  - Hexagonal / ports and adapters (inbound adapters, application/core, outbound adapters),
  - Vertical slices (feature folders/modules with local UI + use-cases + data),
  - Mixed.
- Use folder/package naming and dependency direction to support your conclusion (not just folder names).

4) Build a dependency graph (module level)
- Extract dependencies using imports/usages and known framework wiring.
- Collapse fine-grained nodes into logical components:
  - "API/Controllers", "Use-cases/Services", "Domain", "Repos/Persistence", "External clients", "Messaging", "Jobs", "Config".
- Keep the diagram readable:
  - Max ~60 nodes per diagram.
  - Prefer directory/module nodes over individual classes.
  - If huge, output 1 high-level diagram + 1 per service/package.

5) Mark architectural issues directly in the diagram
Flag and highlight (with red edges or a "VIOLATION" label) when you find evidence of:
- Domain/core depending on infrastructure/frameworks (imports from core to infra, ORM, web frameworks).
- Controllers/handlers directly using DB/ORM without an application/service boundary.
- Cyclic dependencies between modules.
- Cross-slice calls that bypass intended boundaries (feature A directly reaching into feature B internals).
- Business logic living in UI/controllers (large conditional logic, rules, workflows).
- Over-shared "utils/common" used across unrelated modules (suggest missing boundaries).

Deliverables (output format requirements)
A) Mermaid diagram (required): "Architecture Overview"
- Use mermaid flowchart.
- Use subgraphs to represent boundaries:
  - If layered: subgraphs for layers.
  - If vertical slices: subgraphs per slice, and inside each slice show the local layering.
  - If hexagonal: subgraphs for inbound adapters, application/core, outbound adapters.
- Nodes must include short names plus path hints in parentheses, for example: "OrdersService (src/orders/service)".
- Edges are directed from caller to callee and labeled with intent: "calls", "reads", "writes", "publishes", "subscribes".
- Use dashed edges for uncertain relationships.
- Make DB/external systems obvious using distinct node labels like "Postgres (db)", "Redis (cache)", "S3 (object storage)", "Stripe API (external)".
- Include a small Legend subgraph explaining:
  - solid vs dashed edges
  - what a red "VIOLATION" edge means
  - shapes or naming conventions you used

B) Mermaid diagram (optional but recommended if large): "Dependency Boundaries"
- A simplified boundary-only graph: boundaries as nodes, edges as dependency directions.
- Highlight cycles and forbidden directions.

C) Issues list (required)
- Bullet list of the top architectural issues found (max 10), each with:
  - what you observed (with file/module examples),
  - why it is a problem,
  - a concrete fix direction (for example introduce a port/interface, move code, split module).

Mermaid styling guidance (use if supported by your renderer)
- Use class styles to visually distinguish categories:
  - inbound (UI/API/CLI/consumers),
  - application/use-cases,
  - domain/core,
  - infrastructure (DB, external clients),
  - shared/cross-cutting (auth, logging, config).
- Use red stroke or "VIOLATION" labels on forbidden edges.
- If styling is not supported, encode categories in node labels like "[INBOUND]" "[DOMAIN]" etc.

Now run the analysis and output:
1) Mermaid "Architecture Overview"
2) Mermaid "Dependency Boundaries" (if needed for clarity)
3) Issues list