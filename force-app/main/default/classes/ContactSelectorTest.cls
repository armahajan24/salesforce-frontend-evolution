@IsTest
private class ContactSelectorTest {
    @IsTest
    static void getByAccountIdReturnsOnlyThatAccountsContacts() {
        Account acc1 = TestDataFactory.createAccount('Acme Rockets');
        Account acc2 = TestDataFactory.createAccount('Globex Inc');
        TestDataFactory.createContacts(acc1.Id, 3);
        TestDataFactory.createContacts(acc2.Id, 2);

        Test.startTest();
        List<Contact> results = ContactSelector.getByAccountId(acc1.Id);
        Test.stopTest();

        System.assertEquals(3, results.size(), 'Only acc1 contacts should be returned');
    }

    @IsTest
    static void getByAccountIdReturnsEmptyForAccountWithNoContacts() {
        Account acc = TestDataFactory.createAccount('Acme Rockets');

        Test.startTest();
        List<Contact> results = ContactSelector.getByAccountId(acc.Id);
        Test.stopTest();

        System.assertEquals(0, results.size(), 'An Account with no Contacts should return an empty list, not null');
    }

    @IsTest
    static void getByAccountIdIsCappedAtRowLimit() {
        Account acc = TestDataFactory.createAccount('Acme Rockets');
        TestDataFactory.createContacts(acc.Id, 210);

        Test.startTest();
        List<Contact> results = ContactSelector.getByAccountId(acc.Id);
        Test.stopTest();

        System.assertEquals(200, results.size(), 'Result set must be capped at 200 rows regardless of how many exist');
    }
}
