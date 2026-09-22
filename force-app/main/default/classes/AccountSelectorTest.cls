@IsTest
private class AccountSelectorTest {
    @TestSetup
    static void setup() {
        TestDataFactory.createAccount('Acme Rockets');
        TestDataFactory.createAccount('Acme Robotics');
        TestDataFactory.createAccount('Globex Inc');
    }

    @IsTest
    static void searchByNameReturnsMatchingAccountsOnly() {
        Test.startTest();
        List<Account> results = AccountSelector.searchByName('Acme');
        Test.stopTest();

        System.assertEquals(2, results.size(), 'Expected only the two Acme accounts to match');
    }

    @IsTest
    static void searchByNameWithInjectionAttemptIsSafeAndMatchesNothing() {
        Test.startTest();
        // A malicious/edge-case search term must not throw and must not match everything.
        // Protection comes from the :likeTerm bind variable (Apex parameterizes it),
        // not from manual string escaping - a SOQL bind variable is never interpreted
        // as query syntax regardless of its literal content.
        List<Account> results = AccountSelector.searchByName('\' OR Name != \'');
        Test.stopTest();

        System.assertEquals(0, results.size(), 'A bind-variable value must never be interpreted as SOQL syntax');
    }

    @IsTest
    static void searchByNameMatchesNamesContainingApostrophes() {
        TestDataFactory.createAccount('O\'Reilly Manufacturing');

        Test.startTest();
        List<Account> results = AccountSelector.searchByName('O\'Reilly');
        Test.stopTest();

        System.assertEquals(1, results.size(), 'A literal apostrophe in the search term must still match, not be double-escaped');
    }

    @IsTest
    static void searchByNameWithBlankTermReturnsEmpty() {
        Test.startTest();
        List<Account> results = AccountSelector.searchByName('%');
        Test.stopTest();

        System.assertEquals(3, results.size(), 'A bare wildcard should still just LIKE-match all seeded accounts');
    }

    @IsTest
    static void getByIdReturnsNullForDeletedId() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'Globex Inc' LIMIT 1];
        Id deletedId = acc.Id;
        delete acc;

        Test.startTest();
        Account result = AccountSelector.getById(deletedId);
        Test.stopTest();

        System.assertEquals(null, result, 'A deleted/non-existent Account should resolve to null, not an exception');
    }
}
