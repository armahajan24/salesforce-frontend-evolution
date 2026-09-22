@IsTest
private class AccountDashboardControllerTest {
    @IsTest
    static void searchAccountsDelegatesToService() {
        TestDataFactory.createAccount('Acme Rockets');

        Test.startTest();
        List<AccountDashboardDTO.AccountOption> results = AccountDashboardController.searchAccounts('Acme');
        Test.stopTest();

        System.assertEquals(1, results.size());
    }

    @IsTest
    static void getOpportunityStagesReturnsActivePicklistValues() {
        Test.startTest();
        List<String> stages = AccountDashboardController.getOpportunityStages();
        Test.stopTest();

        System.assert(stages.contains('Prospecting'));
        System.assert(stages.contains('Closed Won'));
    }

    @IsTest
    static void getDashboardReturnsDataForValidAccount() {
        Account acc = TestDataFactory.createAccount('Acme Rockets');
        TestDataFactory.createOpportunities(acc.Id, 2);

        Test.startTest();
        AccountDashboardDTO.DashboardResult result = AccountDashboardController.getDashboard(acc.Id);
        Test.stopTest();

        System.assertEquals(2, result.opportunities.size());
    }

    @IsTest
    static void getDashboardWithInvalidAccountThrowsAuraHandledExceptionWithMessage() {
        Boolean threw = false;
        String message;
        try {
            AccountDashboardController.getDashboard(null);
        } catch (AuraHandledException e) {
            threw = true;
            message = e.getMessage();
        }
        System.assertEquals(true, threw);
        System.assertNotEquals('Script-thrown exception', message, 'AuraHandledException.setMessage() must be called or the client sees a generic placeholder');
    }

    @IsTest
    static void updateOpportunityStageDelegatesToService() {
        Account acc = TestDataFactory.createAccount('Acme Rockets');
        Opportunity opp = TestDataFactory.createOpportunities(acc.Id, 1)[0];

        Test.startTest();
        AccountDashboardController.updateOpportunityStage(opp.Id, 'Closed Won');
        Test.stopTest();

        Opportunity updated = [SELECT StageName FROM Opportunity WHERE Id = :opp.Id];
        System.assertEquals('Closed Won', updated.StageName);
    }

    @IsTest
    static void getDashboardWithInsufficientPermissionsThrowsSafeAuraHandledException() {
        Account acc = TestDataFactory.createAccount('Acme Rockets');
        User restrictedUser = TestDataFactory.createMinimumAccessUser();

        Boolean threw = false;
        String message;
        System.runAs(restrictedUser) {
            try {
                AccountDashboardController.getDashboard(acc.Id);
            } catch (AuraHandledException e) {
                threw = true;
                message = e.getMessage();
            }
        }

        System.assertEquals(true, threw, 'A user without object access must be rejected, not crash');
        System.assert(!message.contains('System.'), 'Raw Apex/QueryException internals must not leak to the client');
    }

    @IsTest
    static void updateOpportunityStageWithInvalidStageThrowsAuraHandledException() {
        Account acc = TestDataFactory.createAccount('Acme Rockets');
        Opportunity opp = TestDataFactory.createOpportunities(acc.Id, 1)[0];

        Boolean threw = false;
        try {
            AccountDashboardController.updateOpportunityStage(opp.Id, 'Not A Real Stage');
        } catch (AuraHandledException e) {
            threw = true;
        }
        System.assertEquals(true, threw);
    }
}
