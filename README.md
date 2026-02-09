# Multi-Agent Workflow System

A collection of structured, multi-agent workflows for software development tasks. Each workflow consists of specialized AI agents that work sequentially to accomplish specific engineering goals.

## 🎯 Quick Start: Which Workflow?

```
What are you doing?
│
├─ 🆕 Building NEW feature
│  ├─ Requirements clear?     → Spec-Driven Development
│  └─ Solution unknown?       → Spike & Feasibility (then SDD)
│
├─ 🐛 Fixing BUG
│  ├─ Simple, clear symptom?  → Autonomous Bug Fix
│  └─ Complex/unknown cause?  → Bug Forensics
│
└─ ♻️ Improving CODE (no behavior change)
   └─ Refactoring/cleanup?    → Refactor Safety
```

---

## 📚 Available Workflows

### 1️⃣ Spec-Driven Development (SDD)
**Purpose**: Build new features with clear requirements
**Use when**: You know WHAT you want to build

**Agent sequence**:
```
Architect → Investigator → Planner → Implementer
   PRD         RESEARCH       PLAN      Code+Tests+DOD
```

**Output**: Production-ready feature with tests
**Location**: `prompts/spec-driven-development/`

---

### 2️⃣ Bug Forensics
**Purpose**: Deep investigation of complex bugs
**Use when**: Root cause unclear, needs analysis

**Agent sequence**:
```
Investigator → Planner → Implementer (optional)
ROOT_CAUSE      FIX_PLAN   Code+Tests+DOD
```

**Key features**:
- Uncertainty flags
- Manual validation guide
- Human checkpoint between stages
- Evidence-based analysis

**Output**: Root cause analysis + fix plan
**Location**: `prompts/bug-forensics/`

---

### 3️⃣ Autonomous Bug Fix
**Purpose**: Fast fixes for clear, simple bugs
**Use when**: Symptoms obvious, high confidence

**Agent sequence**:
```
Investigator → Implementer
DIAGNOSIS      Code+Tests+FIX
```

**Key features**:
- No human checkpoints
- Built-in regression checklist
- Every fix cites failure signal

**Output**: Automated fix with tests
**Location**: `prompts/autonomous-bug-fix/`

---

### 4️⃣ Refactor Safety
**Purpose**: Code quality improvements with ZERO behavior change
**Use when**: Refactoring, extracting, cleaning up

**Agent sequence**:
```
Architect → Investigator → Planner → Implementer
BASELINE   BASELINE_RESEARCH  REFACTOR_PLAN  Code+Tests+DOD
```

**Key features**:
- Behavioral invariants defined upfront
- Snapshot tests for equivalence
- Forbidden changes documented

**Output**: Refactored code with proof of equivalence
**Location**: `prompts/refactor-safety/`

---

### 5️⃣ Spike & Feasibility
**Purpose**: Explore unknown solutions, compare approaches
**Use when**: Don't know HOW to solve it

**Agent sequence**:
```
Architect → Explorer → Decision
  SPIKE      EXPLORATION  DECISION.md
```

**Key features**:
- NO implementation produced
- Throwaway experiments only
- Compares multiple approaches
- Recommends one path forward

**Output**: Decision brief with recommendation
**Location**: `prompts/spike-and-feasibility/`

⚠️ **Next step**: Promote chosen approach to SDD workflow for implementation

---

## 🔄 Common Pattern

All workflows follow the same mental model with variations:

1. **Establish Truth** - What is the current state?
2. **Define Intent** - What are we trying to achieve?
3. **Plan Verification** - How do we prove it works?
4. **Execute** - Implement with validation

**Variations by**:
- Human checkpoints (Forensics) vs autonomous (Auto Bug Fix)
- Uncertainty handling (explicit unknowns vs confidence)
- Blast radius control (Refactor Safety vs new features)

---

## 📖 How to Use

1. **Choose workflow** using decision tree above
2. **Run agents sequentially** - each agent reads previous output
3. **Review artifacts** - each agent produces markdown documents
4. **Provide feedback** between agents if needed
5. **Implement** using final Implementer agent

### Example: New Feature

```bash
# 1. Create PRD
Use: prompts/spec-driven-development/architect.md
Output: features/user-export/PRD.md

# 2. Investigate codebase
Use: prompts/spec-driven-development/investigator.md
Input: PRD.md
Output: features/user-export/RESEARCH.md

# 3. Create implementation plan
Use: prompts/spec-driven-development/planner.md
Input: PRD.md + RESEARCH.md
Output: features/user-export/PLAN.md

# 4. Implement
Use: prompts/spec-driven-development/implementer.md
Input: All previous artifacts
Output: Working code + tests
```

---

## 🎓 Workflow Selection Examples

| Scenario | Workflow | Reason |
|----------|----------|--------|
| "Add CSV export for users" | Spec-Driven Development | Clear feature request |
| "Should we use Redis or Memcached?" | Spike & Feasibility | Need to explore options |
| "Payment fails for UK customers" | Bug Forensics | Complex, needs investigation |
| "Login button doesn't work" | Autonomous Bug Fix | Clear, simple symptom |
| "Extract shared auth logic" | Refactor Safety | No behavior change |
| "Optimize slow query" | Refactor Safety | (if behavior unchanged) |
| "Redesign notification system" | Spike → SDD | Research first, then build |

---

## 📁 Repository Structure

```
prompts/
├─ spec-driven-development/     # Full feature workflow
│  ├─ architect.md
│  ├─ investigator.md
│  ├─ planner.md
│  └─ implementer.md
│
├─ bug-forensics/               # Deep bug investigation
│  ├─ investigator.md
│  ├─ planner.md
│  └─ implementer.md
│
├─ autonomous-bug-fix/          # Fast autonomous fixes
│  ├─ investigator.md
│  └─ implementer.md
│
├─ refactor-safety/             # Safe refactoring
│  ├─ architect.md
│  ├─ investigator.md
│  ├─ planner.md
│  └─ implementer.md
│
└─ spike-and-feasibility/       # Exploration & research
   ├─ architect.md
   ├─ explorer.md
   └─ decision.md
```

---

## 🔗 See Also

- **AGENTS.md** - Detailed workflow descriptions and agent behaviors
- **skills/** - Domain-specific knowledge modules