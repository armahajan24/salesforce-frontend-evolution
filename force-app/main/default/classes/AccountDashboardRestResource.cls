/**
 * Apex REST endpoint used ONLY by the React/Multi-Framework app.
 *
 * React Multi-Framework apps cannot invoke @AuraEnabled Apex methods, @wire,
 * or lightning/uiRecordApi (they run entirely outside the LWC/Aura runtime).
 * The Salesforce Multi-Framework Data SDK's `dataSdk.fetch()` is documented as
 * the supported way to reach custom server logic that GraphQL/UI API doesn't
 * cover, specifically by calling an Apex REST (@RestResource) endpoint like
 * this one. This is the one piece of backend surface that could NOT be shared
 * via the same @AuraEnabled controller the Aura/LWC implementations use - it's
 * a platform boundary, not a design choice.
 *
 * @RestResource classes are required by the platform to be declared `global`.
 */
@RestResource(urlMapping='/AccountDashboard/*')
global with sharing class AccountDashboardRestResource {
    @HttpGet
    global static void handleGet() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        res.addHeader('Content-Type', 'application/json');
        try {
            String path = req.requestURI;
            if (path.endsWith('/search')) {
                String term = req.params.get('term');
                res.responseBody = Blob.valueOf(JSON.serialize(AccountDashboardService.searchAccounts(term)));
            } else if (path.endsWith('/stages')) {
                res.responseBody = Blob.valueOf(JSON.serialize(AccountDashboardService.getOpportunityStageNames()));
            } else {
                List<String> parts = path.split('/');
                Id accountId = Id.valueOf(parts.get(parts.size() - 1));
                res.responseBody = Blob.valueOf(JSON.serialize(AccountDashboardService.getDashboard(accountId)));
            }
            res.statusCode = 200;
        } catch (AccountDashboardService.DashboardException e) {
            writeError(res, 400, e.getMessage());
        } catch (Exception e) {
            writeError(res, 500, 'Unable to process the request right now. Please try again.');
        }
    }

    @HttpPatch
    global static void handlePatch() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        res.addHeader('Content-Type', 'application/json');
        try {
            Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(req.requestBody.toString());
            Id opportunityId = Id.valueOf(String.valueOf(body.get('opportunityId')));
            String stageName = String.valueOf(body.get('stageName'));
            AccountDashboardService.updateOpportunityStage(opportunityId, stageName);
            res.statusCode = 204;
        } catch (AccountDashboardService.DashboardException e) {
            writeError(res, 400, e.getMessage());
        } catch (Exception e) {
            writeError(res, 500, 'Unable to update the Opportunity Stage right now. Please try again.');
        }
    }

    private static void writeError(RestResponse res, Integer statusCode, String message) {
        res.statusCode = statusCode;
        res.responseBody = Blob.valueOf(JSON.serialize(new Map<String, String>{ 'error' => message }));
    }
}
