@IsTest
private class VisualforceDashboardControllerTest {
    @IsTest
    static void searchAndSelectLoadsDashboard() {
        Account acc = TestDataFactory.createAccount('Acme Rockets');
        TestDataFactory.createContacts(acc.Id, 1);
        TestDataFactory.createOpportunities(acc.Id, 2);

        VisualforceAccountDashboardController controller = new VisualforceAccountDashboardController();
        controller.searchTerm = 'Acme';

        Test.startTest();
        List<SelectOption> options = controller.getAccountOptions();
        controller.selectedAccountId = acc.Id;
        controller.selectAccount();
        Test.stopTest();

        System.assertEquals(2, options.size(), 'Placeholder option plus one matching Account');
        System.assertEquals(true, controller.getHasAccount());
        System.assertEquals(1, controller.getContacts().size());
        System.assertEquals(2, controller.getFilteredOpportunities().size());
        System.assertEquals(false, controller.getHasError());
    }

    @IsTest
    static void selectingUnknownAccountSetsErrorMessage() {
        VisualforceAccountDashboardController controller = new VisualforceAccountDashboardController();
        controller.selectedAccountId = null;

        Test.startTest();
        controller.selectAccount();
        Test.stopTest();

        System.assertEquals(true, controller.getHasError());
        System.assertEquals(false, controller.getHasAccount());
    }

    @IsTest
    static void gettersBeforeAnyAccountIsSelectedReturnSafeDefaults() {
        VisualforceAccountDashboardController controller = new VisualforceAccountDashboardController();

        System.assertEquals(null, controller.getAccountSummary());
        System.assertEquals(false, controller.getHasContacts());
        System.assertEquals(false, controller.getHasOpportunities());
        System.assertEquals(0, controller.getFilteredOpportunities().size());
    }

    @IsTest
    static void stageOptionsAndOpportunityPickerAreDerivedFromTheLoadedDashboard() {
        Account acc = TestDataFactory.createAccount('Acme Rockets');
        TestDataFactory.createOpportunities(acc.Id, 2);

        VisualforceAccountDashboardController controller = new VisualforceAccountDashboardController();
        controller.selectedAccountId = acc.Id;
        controller.selectAccount();

        Test.startTest();
        List<SelectOption> stageOptions = controller.getStageOptions();
        List<SelectOption> opportunityOptions = controller.getOpportunityOptionsForUpdate();
        Test.stopTest();

        System.assert(stageOptions.size() > 1, 'Should include the "All Stages" placeholder plus real picklist values');
        System.assertEquals(3, opportunityOptions.size(), 'Placeholder plus the two seeded Opportunities');
        System.assertEquals(false, controller.getHasContacts(), 'No Contacts were seeded for this Account');
    }

    @IsTest
    static void doSearchAndApplyStageFilterResetStateWithoutError() {
        VisualforceAccountDashboardController controller = new VisualforceAccountDashboardController();
        controller.selectedAccountId = null;

        Test.startTest();
        PageReference searchResult = controller.doSearch();
        PageReference filterResult = controller.applyStageFilter();
        Test.stopTest();

        System.assertEquals(null, searchResult);
        System.assertEquals(null, filterResult);
        System.assertEquals(false, controller.getHasAccount());
    }

    @IsTest
    static void selectAccountWithInsufficientPermissionsShowsSafeErrorMessage() {
        Account acc = TestDataFactory.createAccount('Acme Rockets');
        User restrictedUser = TestDataFactory.createMinimumAccessUser();

        VisualforceAccountDashboardController controller = new VisualforceAccountDashboardController();
        controller.selectedAccountId = acc.Id;

        System.runAs(restrictedUser) {
            controller.selectAccount();
        }

        System.assertEquals(true, controller.getHasError());
        System.assertEquals(false, controller.getHasAccount());
    }

    @IsTest
    static void stageFilterNarrowsOpportunitiesAndRecalculatesTotal() {
        Account acc = TestDataFactory.createAccount('Acme Rockets');
        TestDataFactory.createOpportunities(acc.Id, 4); // stages cycle Prospecting, Qualification, Proposal/Price Quote, Closed Won

        VisualforceAccountDashboardController controller = new VisualforceAccountDashboardController();
        controller.selectedAccountId = acc.Id;
        controller.selectAccount();

        Test.startTest();
        controller.stageFilter = 'Prospecting';
        List<AccountDashboardDTO.OpportunityRow> filtered = controller.getFilteredOpportunities();
        Decimal total = controller.getPipelineTotal();
        Test.stopTest();

        System.assertEquals(1, filtered.size());
        System.assertEquals(filtered[0].amount, total);
    }

    @IsTest
    static void saveStageUpdateAppliesChangeAndReloadsDashboard() {
        Account acc = TestDataFactory.createAccount('Acme Rockets');
        Opportunity opp = TestDataFactory.createOpportunities(acc.Id, 1)[0];

        VisualforceAccountDashboardController controller = new VisualforceAccountDashboardController();
        controller.selectedAccountId = acc.Id;
        controller.selectAccount();
        controller.editingOpportunityId = opp.Id;
        controller.newStageValue = 'Closed Won';

        Test.startTest();
        controller.saveStageUpdate();
        Test.stopTest();

        System.assertEquals(false, controller.getHasError());
        System.assertEquals('Closed Won', controller.getFilteredOpportunities()[0].stageName);
    }

    @IsTest
    static void saveStageUpdateWithInvalidStageSetsErrorMessage() {
        Account acc = TestDataFactory.createAccount('Acme Rockets');
        Opportunity opp = TestDataFactory.createOpportunities(acc.Id, 1)[0];

        VisualforceAccountDashboardController controller = new VisualforceAccountDashboardController();
        controller.selectedAccountId = acc.Id;
        controller.selectAccount();
        controller.editingOpportunityId = opp.Id;
        controller.newStageValue = 'Not A Real Stage';

        Test.startTest();
        controller.saveStageUpdate();
        Test.stopTest();

        System.assertEquals(true, controller.getHasError());
    }
}
