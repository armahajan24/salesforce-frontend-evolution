/**
 * @AuraEnabled entry point shared by BOTH the Aura and the LWC implementations.
 * Sharing one controller across Aura/LWC is fair (they use the same Lightning
 * Component Framework calling convention); Visualforce and React each need a
 * different entry point because their calling conventions differ (see
 * VisualforceAccountDashboardController and AccountDashboardRestResource).
 */
public with sharing class AccountDashboardController {
    @AuraEnabled(cacheable=true)
    public static List<AccountDashboardDTO.AccountOption> searchAccounts(String searchTerm) {
        try {
            return AccountDashboardService.searchAccounts(searchTerm);
        } catch (Exception e) {
            throw wrapError('Unable to search Accounts right now. Please try again.');
        }
    }

    @AuraEnabled(cacheable=true)
    public static AccountDashboardDTO.DashboardResult getDashboard(Id accountId) {
        try {
            return AccountDashboardService.getDashboard(accountId);
        } catch (AccountDashboardService.DashboardException e) {
            throw wrapError(e.getMessage());
        } catch (Exception e) {
            throw wrapError('Unable to load the Account dashboard right now. Please try again.');
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<String> getOpportunityStages() {
        return AccountDashboardService.getOpportunityStageNames();
    }

    @AuraEnabled
    public static void updateOpportunityStage(Id opportunityId, String newStageName) {
        try {
            AccountDashboardService.updateOpportunityStage(opportunityId, newStageName);
        } catch (AccountDashboardService.DashboardException e) {
            throw wrapError(e.getMessage());
        } catch (Exception e) {
            throw wrapError('Unable to update the Opportunity Stage right now. Please try again.');
        }
    }

    /**
     * AuraHandledException's message is not visible to client code unless
     * setMessage() is called explicitly on top of the constructor argument -
     * a well-known Apex gotcha. Centralized here so every method gets it right.
     */
    private static AuraHandledException wrapError(String message) {
        AuraHandledException ex = new AuraHandledException(message);
        ex.setMessage(message);
        return ex;
    }
}
