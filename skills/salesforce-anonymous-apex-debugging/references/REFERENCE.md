# Reference: Salesforce Anonymous Apex Debugging

## Logging fundamentals

You need a trace flag for the executing user, plus debug levels.

Concepts:

- Trace flag: defines who gets logged and for how long.
- Debug levels: control how much is logged per category.
- Class tracing: override log levels for a specific Apex class or trigger.

Practical guidance:

- If you see no log, confirm the trace flag is on for the user that executed the anonymous Apex.
- If your log is huge or truncated, lower global verbosity and use class tracing for the target code.

## Log size and retention

Typical constraints to plan around:

- Logs can be truncated when they exceed size limits.
- Debug logs are retained for a limited time.

Mitigation:

- Use a unique token marker and log at ERROR level for your own markers.
- Avoid logging massive lists or full sObjects with many fields.

## Quick log triage checklist

1. Find your token marker lines.
2. Find the first EXCEPTION_THROWN or FATAL_ERROR.
3. Read the stack trace to the first class line in your code.
4. Inspect the last SOQL and DML before the exception.
5. Inspect cumulative limits and deltas.

## Governor limit diagnosis

Patterns to look for:

- SOQL inside loops
- DML inside loops
- Inefficient string operations (CPU)
- Large in memory collections (heap)

Instrumentation snippet:

```apex
Integer q0 = Limits.getQueries();
Integer cpu0 = Limits.getCpuTime();

MyService.doWork(recordId);

System.debug(LoggingLevel.ERROR,
    'MYBUG|delta queries=' + (Limits.getQueries() - q0)
    + ' deltaCpu=' + (Limits.getCpuTime() - cpu0)
);
```

## DML error extraction pattern

```apex
Database.SaveResult sr = Database.insert(obj, false);
if (!sr.isSuccess()) {
    for (Database.Error err : sr.getErrors()) {
        System.debug(LoggingLevel.ERROR,
            'MYBUG|dml status=' + err.getStatusCode() + ' msg=' + err.getMessage());
    }
}
```

## Safe query pattern

Avoid single row assignment when a missing record is plausible.

```apex
List<Account> accts = [SELECT Id FROM Account WHERE Id = :acctId LIMIT 1];
System.assert(!accts.isEmpty(), 'MYBUG|Account not found: ' + acctId);
Account a = accts[0];
```

## Replay Debugger notes

Replay debugging is log driven.

Guidelines:

- Generate a fresh log for the exact code version you will debug.
- Set breakpoints in the relevant Apex classes.
- Use checkpoints only when you need deep variable inspection.

## Suggested external docs

- Agent Skills spec: https://agentskills.io/specification
- Apex debugging logs and Developer Console docs in Salesforce help
- Salesforce CLI commands for Apex run and log retrieval
