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
    static void searchByNameEscapesSpecialCharacters() {
        Test.startTest();
        // A malicious/edge-case search term must not throw and must not match everything.
        List<Account> results = AccountSelector.searchByName('\' OR Name != \'');
        Test.stopTest();

        System.assertEquals(0, results.size(), 'Special characters must be escaped, not interpreted as SOQL');
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
