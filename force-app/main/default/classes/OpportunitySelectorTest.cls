@IsTest
private class OpportunitySelectorTest {
    @IsTest
    static void getByAccountIdReturnsOnlyThatAccountsOpportunities() {
        Account acc1 = TestDataFactory.createAccount('Acme Rockets');
        Account acc2 = TestDataFactory.createAccount('Globex Inc');
        TestDataFactory.createOpportunities(acc1.Id, 4);
        TestDataFactory.createOpportunities(acc2.Id, 2);

        Test.startTest();
        List<Opportunity> results = OpportunitySelector.getByAccountId(acc1.Id);
        Test.stopTest();

        System.assertEquals(4, results.size(), 'Only acc1 opportunities should be returned');
    }

    @IsTest
    static void getByAccountIdIsCappedAtRowLimit() {
        Account acc = TestDataFactory.createAccount('Acme Rockets');
        TestDataFactory.createOpportunities(acc.Id, 250);

        Test.startTest();
        List<Opportunity> results = OpportunitySelector.getByAccountId(acc.Id);
        Test.stopTest();

        System.assertEquals(200, results.size(), 'Result set must be capped at 200 rows for a large-enough dataset');
    }

    @IsTest
    static void updateStageChangesTheStageName() {
        Account acc = TestDataFactory.createAccount('Acme Rockets');
        Opportunity opp = TestDataFactory.createOpportunities(acc.Id, 1)[0];

        Test.startTest();
        OpportunitySelector.updateStage(opp.Id, 'Closed Won');
        Test.stopTest();

        Opportunity updated = [SELECT StageName FROM Opportunity WHERE Id = :opp.Id];
        System.assertEquals('Closed Won', updated.StageName);
    }

    @IsTest
    static void updateStageWithInvalidPicklistValueThrows() {
        Account acc = TestDataFactory.createAccount('Acme Rockets');
        Opportunity opp = TestDataFactory.createOpportunities(acc.Id, 1)[0];

        Boolean threw = false;
        Test.startTest();
        try {
            OpportunitySelector.updateStage(opp.Id, 'Not A Real Stage');
        } catch (Exception e) {
            threw = true;
        }
        Test.stopTest();

        System.assertEquals(true, threw, 'An invalid Stage value must raise a DmlException, not silently no-op');
    }
}
