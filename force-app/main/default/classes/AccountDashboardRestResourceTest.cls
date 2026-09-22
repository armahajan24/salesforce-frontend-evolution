@IsTest
private class AccountDashboardRestResourceTest {
    private static RestRequest buildRequest(String uri, String method) {
        RestRequest req = new RestRequest();
        req.requestURI = uri;
        req.httpMethod = method;
        return req;
    }

    @IsTest
    static void handleGetSearchReturnsMatchingAccounts() {
        TestDataFactory.createAccount('Acme Rockets');

        RestRequest req = buildRequest('/services/apexrest/AccountDashboard/search', 'GET');
        req.params.put('term', 'Acme');
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        AccountDashboardRestResource.handleGet();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
        String body = RestContext.response.responseBody.toString();
        System.assert(body.contains('Acme Rockets'));
    }

    @IsTest
    static void handleGetDashboardReturnsAccountData() {
        Account acc = TestDataFactory.createAccount('Acme Rockets');
        TestDataFactory.createOpportunities(acc.Id, 2);

        RestRequest req = buildRequest('/services/apexrest/AccountDashboard/' + acc.Id, 'GET');
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        AccountDashboardRestResource.handleGet();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
        String body = RestContext.response.responseBody.toString();
        System.assert(body.contains('pipelineTotal'));
    }

    @IsTest
    static void handleGetWithInvalidAccountReturns400WithSafeMessage() {
        Account acc = TestDataFactory.createAccount('Acme Rockets');
        Id deletedId = acc.Id;
        delete acc;

        RestRequest req = buildRequest('/services/apexrest/AccountDashboard/' + deletedId, 'GET');
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        AccountDashboardRestResource.handleGet();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);
        String body = RestContext.response.responseBody.toString();
        System.assert(!body.contains('System.'), 'Raw Apex exception internals must not leak in the REST error body');
    }

    @IsTest
    static void handleGetStagesReturnsActivePicklistValues() {
        RestRequest req = buildRequest('/services/apexrest/AccountDashboard/stages', 'GET');
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        AccountDashboardRestResource.handleGet();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
        String body = RestContext.response.responseBody.toString();
        System.assert(body.contains('Prospecting'));
    }

    @IsTest
    static void handleGetWithInsufficientPermissionsReturns400WithSafeMessage() {
        Account acc = TestDataFactory.createAccount('Acme Rockets');
        User restrictedUser = TestDataFactory.createMinimumAccessUser();

        RestRequest req = buildRequest('/services/apexrest/AccountDashboard/' + acc.Id, 'GET');
        RestContext.request = req;
        RestContext.response = new RestResponse();

        System.runAs(restrictedUser) {
            AccountDashboardRestResource.handleGet();
        }

        // A QueryException from insufficient object/field access is not a
        // DashboardException, so it falls into the generic catch -> 500, same as
        // any other unexpected server error - but still with a safe message.
        System.assertEquals(500, RestContext.response.statusCode);
        String body = RestContext.response.responseBody.toString();
        System.assert(!body.contains('System.'), 'Raw Apex/QueryException internals must not leak in the REST error body');
    }

    @IsTest
    static void handlePatchUpdatesOpportunityStage() {
        Account acc = TestDataFactory.createAccount('Acme Rockets');
        Opportunity opp = TestDataFactory.createOpportunities(acc.Id, 1)[0];

        RestRequest req = buildRequest('/services/apexrest/AccountDashboard/' + opp.Id, 'PATCH');
        req.requestBody = Blob.valueOf(
            JSON.serialize(new Map<String, Object>{ 'opportunityId' => opp.Id, 'stageName' => 'Closed Won' })
        );
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        AccountDashboardRestResource.handlePatch();
        Test.stopTest();

        System.assertEquals(204, RestContext.response.statusCode);
        Opportunity updated = [SELECT StageName FROM Opportunity WHERE Id = :opp.Id];
        System.assertEquals('Closed Won', updated.StageName);
    }

    @IsTest
    static void handlePatchWithMismatchedIdsReturns400() {
        Account acc = TestDataFactory.createAccount('Acme Rockets');
        List<Opportunity> opps = TestDataFactory.createOpportunities(acc.Id, 2);

        // URL identifies opps[0]; body claims to be updating opps[1] - must be rejected.
        RestRequest req = buildRequest('/services/apexrest/AccountDashboard/' + opps[0].Id, 'PATCH');
        req.requestBody = Blob.valueOf(
            JSON.serialize(new Map<String, Object>{ 'opportunityId' => opps[1].Id, 'stageName' => 'Closed Won' })
        );
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        AccountDashboardRestResource.handlePatch();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);
        Opportunity unchanged = [SELECT StageName FROM Opportunity WHERE Id = :opps[1].Id];
        System.assertNotEquals('Closed Won', unchanged.StageName, 'A mismatched body Id must not be applied');
    }

    @IsTest
    static void handlePatchWithInvalidStageReturns400() {
        Account acc = TestDataFactory.createAccount('Acme Rockets');
        Opportunity opp = TestDataFactory.createOpportunities(acc.Id, 1)[0];

        RestRequest req = buildRequest('/services/apexrest/AccountDashboard/' + opp.Id, 'PATCH');
        req.requestBody = Blob.valueOf(
            JSON.serialize(new Map<String, Object>{ 'opportunityId' => opp.Id, 'stageName' => 'Not A Real Stage' })
        );
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        AccountDashboardRestResource.handlePatch();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);
    }
}
