---
name: salesforce-anonymous-apex-debugging
description: Debug Salesforce Apex bugs by building a minimal Execute Anonymous reproduction harness, configuring trace flags and debug levels, capturing and reading debug logs, and using Apex Replay Debugger to pinpoint root cause. Use for exceptions, DML failures, governor limits, sharing and permission issues, trigger recursion, and async follow ups.
license: CC-BY-4.0
compatibility: Requires Salesforce org access. Designed for Developer Console, VS Code Salesforce extensions, and Salesforce CLI (sf). No internet required for core workflow.
metadata:
  author: generated
  version: "1.0"
  category: "salesforce-apex"
---

# Salesforce Anonymous Apex Debugging

## Scope

Use this skill when you need to debug an Apex bug by reproducing it with Execute Anonymous (anonymous Apex) and then analyzing the resulting debug logs.

This skill focuses on:

- Creating a deterministic reproduction harness
- Capturing a high signal debug log (trace flags, log levels, class tracing)
- Reading logs fast (markers, stack traces, limits)
- Using Apex Replay Debugger for step through debugging
- Handling common Apex bug classes (nulls, DML errors, limits, sharing, async)

Do not use this skill for:

- Writing net new Salesforce features
- General Salesforce admin tasks (page layouts, flows) unless they explain a DML or validation failure
- Production fire drills where you cannot safely reproduce and log without risk

## Required inputs

Before running anything, collect:

- The failing entry point: class and method, trigger, batch, queueable, invocable, etc.
- The smallest set of record Ids or parameters that reproduce the issue
- The user context that matters (which user sees the bug)
- The environment: sandbox vs production, Developer Console vs VS Code vs CLI

## Safety rules

Anonymous Apex runs a real transaction.

- Prefer a sandbox, scratch org, or a dedicated dev environment.
- Use a Savepoint and rollback for any DML needed to set up reproduction.
- Avoid callouts, emails, platform events, and other external side effects in your reproduction path.

## Workflow

### 1) Build a minimal reproduction harness

Goal: one script that reliably reproduces the bug in a single run.

Start from the template:

- [assets/anonymous_apex_harness.apex](assets/anonymous_apex_harness.apex)

Rules for a good harness:

- Hardcode or deterministically query for the target records
- Select only the fields your code path needs
- Use a unique log token so you can search the log instantly
- Log inputs and outputs in a structured way (key=value style)
- Add assertions to fail early with clear messages

### 2) Configure logging for signal, not noise

You need two things:

- A trace flag so a log is actually produced for the executing user
- Debug levels that capture the categories you need

Recommended baseline debug levels for anonymous Apex:

- Apex Code: FINER or FINEST
- Database: FINER
- System: DEBUG
- Validation: INFO (raise to FINER if validation is suspected)
- Workflow: INFO
- Callout: INFO (raise if callouts are involved)
- Apex Profiling: INFO (raise if CPU is suspected)

Noise control:

- Prefer class tracing on the specific class or trigger you care about.
- Keep broad categories lower to avoid 20 MB log truncation.

### 3) Execute anonymous Apex

Run the harness from your preferred tool:

- Developer Console: Execute Anonymous and open the log
- VS Code: SFDX Execute Anonymous Apex with editor contents
- CLI: sf apex run -f <file>

### 4) Triage the debug log quickly

In the log, do this in order:

1. Search for your token marker (example: MYBUG|)
2. Find the first EXCEPTION_THROWN or FATAL_ERROR
3. Read the stack trace and note the top Apex line
4. Scroll up to the last marker step to understand inputs and branches
5. Check limits near the end (queries, DML, CPU, heap)

If you have a large log, use the helper script:

- node scripts/extract_log_snippet.js --log /path/to/log.txt --token MYBUG --context 80

### 5) Use Apex Replay Debugger for step through debugging

Use VS Code Apex Replay Debugger when you need variable inspection and exact control flow.

Workflow:

- Set breakpoints in the target class
- Optionally set checkpoints for heap snapshots
- Generate a log by running your anonymous harness
- Launch replay debugging on that log

Tip: keep your source in sync with the org version that generated the log.

### 6) Interpret the result and produce a fix plan

Your output should be:

- Root cause summary: what exactly went wrong and why
- Minimal fix: smallest safe code change
- Regression test plan: how to lock the fix in an Apex test

## Common bug patterns

### Null pointer

- Add assertions on inputs and critical variables right before the failing line.
- Log the specific variable values, not entire large objects.

### List has no rows for assignment

- Query into a list, assert not empty, then take the first element.

### DML exception

- Use Database.* methods with allOrNone=false to capture errors.
- Log status code and message per error.

### Governor limits

- Log deltas in Limits.getQueries(), Limits.getCpuTime(), and heap.
- Look for loops that do SOQL or DML.

### Sharing and permissions

- Reproduce under the same user.
- Confirm whether the code runs with sharing or without sharing.
- Distinguish CRUD and FLS checks from record sharing issues.

### Trigger recursion

- Look for repeated trigger entry in the log.
- Confirm recursion guard behavior in your trigger framework.

### Async follow ups

- Queueable, future, and batch often produce separate logs.
- Capture and inspect each async log separately.

## File references

- Harness template: [assets/anonymous_apex_harness.apex](assets/anonymous_apex_harness.apex)
- Log snippet helper: [scripts/extract_log_snippet.js](scripts/extract_log_snippet.js)
- Deeper reference: [references/REFERENCE.md](references/REFERENCE.md)
