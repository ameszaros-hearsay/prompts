# Multi-Agent Workflow System

This repository contains 5 distinct multi-agent workflows, each designed for specific software engineering scenarios. Each workflow consists of specialized agents that must be invoked sequentially.

## Quick Decision Tree

```
START: What are you trying to do?
│
├─ Build a NEW feature?
│  ├─ Requirements clear? ──YES──> [Spec-Driven Development]
│  └─ Solution unknown?   ──YES──> [Spike & Feasibility] → then SDD
│
├─ Fix a BUG?
│  ├─ Root cause known + high confidence? ──YES──> [Autonomous Bug Fix]
│  └─ Complex investigation needed?       ──YES──> [Bug Forensics]
│
└─ Improve CODE QUALITY (no behavior change)?
   └─> [Refactor Safety]
```

## Workflows Overview

### 1. Spec-Driven Development (SDD)
**When to use**: Building new features with clear requirements
**Output**: Production-ready feature with tests
**Agents** (sequential):
1. **Architect** → `features/{name}/PRD.md`
2. **Investigator** → `features/{name}/RESEARCH.md`
3. **Planner** → `features/{name}/PLAN.md`
4. **Implementer** → Working code + tests + `DOD.md`

**Sequential flow**: Each agent reads the previous output and builds on it.

---

### 2. Bug Forensics
**When to use**: Complex bugs requiring deep investigation
**Output**: Root cause analysis + validated fix
**Agents** (sequential):
1. **Investigator** → `bugs/{name}/ROOT_CAUSE.md`
2. **Planner** → `bugs/{name}/FIX_PLAN.md` (includes manual validation guide)
3. **Implementer** → Fix code + tests (optional, can be done manually)

**Key difference from Autonomous**: Includes human checkpoints and explicit uncertainty flags.

---

### 3. Autonomous Bug Fix
**When to use**: Simple bugs with clear symptoms, trusted LLM judgment
**Output**: Fast, automated fix
**Agents** (sequential):
1. **Investigator** → `bugfix/DIAGNOSIS.md`
2. **Implementer** → Fix code + regression tests + `bugfix/FIX.md`

**Key difference from Forensics**: No human checkpoints, faster execution, built-in regression checklist.

---

### 4. Refactor Safety
**When to use**: Code quality improvements with zero behavioral change
**Output**: Refactored code with behavioral equivalence proof
**Agents** (sequential):
1. **Architect** → `features/{name}/BASELINE.md` (invariants + contracts)
2. **Investigator** → `features/{name}/BASELINE_RESEARCH.md`
3. **Planner** → `features/{name}/REFACTOR_PLAN.md`
4. **Implementer** → Refactored code + snapshot tests + `DOD.md`

**Guardrail**: Every change must preserve behavioral equivalence.

---

### 5. Spike & Feasibility
**When to use**: Solution unknown, need to explore options
**Output**: Decision brief comparing approaches (NO implementation)
**Agents** (sequential):
1. **Architect** → `spikes/{name}/SPIKE.md` (defines exploration scope)
2. **Explorer** → `spikes/{name}/EXPLORATION.md` (throwaway code/research)
3. **Decision** → `spikes/{name}/DECISION.md` (recommends approach)

**Important**: Does NOT produce implementation. Promote to SDD workflow after decision.

---

## Common Pattern

All workflows follow:
1. **Establish Truth** (Architect/Investigator)
2. **Define Intent** (Planner/Explorer)
3. **Plan Verification** (explicit test/validation strategy)
4. **Execute** (Implementer)

Variations exist in:
- Human checkpoints vs autonomous
- Uncertainty handling
- Blast radius control
- Output artifacts

---

## Workflow Selection Guide

| Scenario | Workflow | Why? |
|----------|----------|------|
| "Add user export feature" | Spec-Driven Development | Clear feature intent |
| "Should we use GraphQL or REST?" | Spike & Feasibility | Solution unknown |
| "API returns 500 under load" | Bug Forensics | Needs investigation |
| "Button click doesn't work" | Autonomous Bug Fix | Simple, clear symptom |
| "Extract shared pricing logic" | Refactor Safety | No behavior change |
| "Optimize database queries" | Refactor Safety | If behavior unchanged |
| "Redesign auth system" | Spike → SDD | Research then implement |

---

## Agent Prompts Location

- `prompts/spec-driven-development/` - architect.md, investigator.md, planner.md, implementer.md
- `prompts/bug-forensics/` - investigator.md, planner.md, implementer.md
- `prompts/autonomous-bug-fix/` - investigator.md, implementer.md
- `prompts/refactor-safety/` - architect.md, investigator.md, planner.md, implementer.md
- `prompts/spike-and-feasibility/` - architect.md, explorer.md, decision.md
