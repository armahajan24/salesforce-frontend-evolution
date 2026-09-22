@IsTest
private class AccountDashboardServiceTest {
    @IsTest
    static void getDashboardReturnsAccountContactsOpportunitiesAndTotal() {
        Account acc = TestDataFactory.createAccount('Acme Rockets');
        TestDataFactory.createContacts(acc.Id, 2);
        TestDataFactory.createOpportunities(acc.Id, 3); // amounts: 1000, 2000, 3000

        Test.startTest();
        AccountDashboardDTO.DashboardResult result = AccountDashboardService.getDashboard(acc.Id);
        Test.stopTest();

        System.assertEquals(acc.Id, result.account.id);
        System.assertEquals(2, result.contacts.size());
        System.assertEquals(3, result.opportunities.size());
        System.assertEquals(6000, result.pipelineTotal);
    }

    @IsTest
    static void getDashboardWithNoContactsOrOpportunitiesReturnsEmptyLists() {
        Account acc = TestDataFactory.createAccount('Acme Rockets');

        Test.startTest();
        AccountDashboardDTO.DashboardResult result = AccountDashboardService.getDashboard(acc.Id);
        Test.stopTest();

        System.assertEquals(0, result.contacts.size());
        System.assertEquals(0, result.opportunities.size());
        System.assertEquals(0, result.pipelineTotal);
    }

    @IsTest
    static void getDashboardWithNullIdThrowsDashboardException() {
        Boolean threw = false;
        try {
            AccountDashboardService.getDashboard(null);
        } catch (AccountDashboardService.DashboardException e) {
            threw = true;
        }
        System.assertEquals(true, threw);
    }

    @IsTest
    static void getDashboardWithUnknownIdThrowsDashboardException() {
        Account acc = TestDataFactory.createAccount('Acme Rockets');
        Id validButUnrelatedId = acc.Id;
        delete acc;

        Boolean threw = false;
        String message;
        try {
            AccountDashboardService.getDashboard(validButUnrelatedId);
        } catch (AccountDashboardService.DashboardException e) {
            threw = true;
            message = e.getMessage();
        }
        System.assertEquals(true, threw);
        System.assert(message.contains('not be found') || message.contains('not accessible'));
    }

    @IsTest
    static void searchAccountsWithBlankTermReturnsEmptyWithoutQuerying() {
        Test.startTest();
        List<AccountDashboardDTO.AccountOption> results = AccountDashboardService.searchAccounts('');
        Test.stopTest();

        System.assertEquals(0, results.size());
    }

    @IsTest
    static void updateOpportunityStageWithMissingArgsThrowsDashboardException() {
        Boolean threw = false;
        try {
            AccountDashboardService.updateOpportunityStage(null, 'Closed Won');
        } catch (AccountDashboardService.DashboardException e) {
            threw = true;
        }
        System.assertEquals(true, threw);
    }

    @IsTest
    static void updateOpportunityStageWrapsDmlFailureAsDashboardException() {
        Account acc = TestDataFactory.createAccount('Acme Rockets');
        Opportunity opp = TestDataFactory.createOpportunities(acc.Id, 1)[0];

        Boolean threw = false;
        try {
            AccountDashboardService.updateOpportunityStage(opp.Id, 'Not A Real Stage');
        } catch (AccountDashboardService.DashboardException e) {
            threw = true;
            System.assert(!e.getMessage().contains('System.DmlException'), 'Raw Apex exception internals must not leak to callers');
        }
        System.assertEquals(true, threw);
    }
}
