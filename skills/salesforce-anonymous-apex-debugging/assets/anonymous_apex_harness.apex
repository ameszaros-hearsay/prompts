// Anonymous Apex Harness Template
// Replace placeholders and keep this file small.

Savepoint sp = Database.setSavepoint();

String token = 'MYBUG|' + String.valueOf(Datetime.now().getTime());
System.debug(LoggingLevel.ERROR, token + '|START user=' + UserInfo.getUserName());

try {
    // 1) Select or create the records that reproduce the bug
    Id recordId = '001000000000000AAA'; // TODO replace

    // 2) Query only the fields needed for the code path
    Account a = [
        SELECT Id, Name, OwnerId
        FROM Account
        WHERE Id = :recordId
        LIMIT 1
    ];
    System.debug(LoggingLevel.ERROR, token + '|INPUT account=' + JSON.serializePretty(a));

    // 3) Call a single entry point method
    // Example:
    // MyService.Result r = MyService.doWork(a.Id);
    // System.debug(LoggingLevel.ERROR, token + '|OUTPUT result=' + JSON.serializePretty(r));

    // 4) Assert expected outcomes so failures are loud and early
    System.assertNotEquals(null, a.OwnerId, token + '|OwnerId must be set');

} catch (Exception e) {
    System.debug(LoggingLevel.ERROR, token + '|EXCEPTION type=' + e.getTypeName());
    System.debug(LoggingLevel.ERROR, token + '|EXCEPTION msg=' + e.getMessage());
    System.debug(LoggingLevel.ERROR, token + '|STACK=' + e.getStackTraceString());
    throw e;
} finally {
    System.debug(LoggingLevel.ERROR, token + '|LIMITS queries=' + Limits.getQueries() + '/' + Limits.getLimitQueries()
        + ' dml=' + Limits.getDmlStatements() + '/' + Limits.getLimitDmlStatements()
        + ' cpu=' + Limits.getCpuTime() + '/' + Limits.getLimitCpuTime()
        + ' heap=' + Limits.getHeapSize() + '/' + Limits.getLimitHeapSize());

    Database.rollback(sp);
    System.debug(LoggingLevel.ERROR, token + '|END rolledBack=true');
}
