/**
 * Business logic for the Account 360 dashboard, shared by every UI's entry point
 * (Visualforce controller extension, Aura/LWC @AuraEnabled controller, and the
 * Apex REST resource used by the React/Multi-Framework app).
 *
 * This is the one place bulkification, FLS/CRUD enforcement (via the selectors)
 * and pipeline-total math live, so all four UIs are guaranteed to compute the
 * same numbers from the same query shape.
 */
public with sharing class AccountDashboardService {
    public class DashboardException extends Exception {
    }

    public static List<AccountDashboardDTO.AccountOption> searchAccounts(String searchTerm) {
        List<AccountDashboardDTO.AccountOption> options = new List<AccountDashboardDTO.AccountOption>();
        if (String.isBlank(searchTerm)) {
            return options;
        }
        for (Account acc : AccountSelector.searchByName(searchTerm)) {
            AccountDashboardDTO.AccountOption opt = new AccountDashboardDTO.AccountOption();
            opt.id = acc.Id;
            opt.name = acc.Name;
            options.add(opt);
        }
        return options;
    }

    public static AccountDashboardDTO.DashboardResult getDashboard(Id accountId) {
        if (accountId == null) {
            throw new DashboardException('An Account must be selected.');
        }

        Account acc = AccountSelector.getById(accountId);
        if (acc == null) {
            throw new DashboardException('The selected Account could not be found or is not accessible.');
        }

        AccountDashboardDTO.AccountSummary summary = new AccountDashboardDTO.AccountSummary();
        summary.id = acc.Id;
        summary.name = acc.Name;
        summary.industry = acc.Industry;
        summary.phone = acc.Phone;
        summary.ownerName = acc.Owner != null ? acc.Owner.Name : null;
        summary.billingCity = acc.BillingCity;
        summary.billingState = acc.BillingState;

        List<AccountDashboardDTO.ContactRow> contactRows = new List<AccountDashboardDTO.ContactRow>();
        for (Contact c : ContactSelector.getByAccountId(accountId)) {
            AccountDashboardDTO.ContactRow row = new AccountDashboardDTO.ContactRow();
            row.id = c.Id;
            row.name = c.Name;
            row.title = c.Title;
            row.email = c.Email;
            row.phone = c.Phone;
            contactRows.add(row);
        }

        List<AccountDashboardDTO.OpportunityRow> oppRows = new List<AccountDashboardDTO.OpportunityRow>();
        Decimal pipelineTotal = 0;
        for (Opportunity o : OpportunitySelector.getByAccountId(accountId)) {
            AccountDashboardDTO.OpportunityRow row = new AccountDashboardDTO.OpportunityRow();
            row.id = o.Id;
            row.name = o.Name;
            row.stageName = o.StageName;
            row.amount = o.Amount == null ? 0 : o.Amount;
            row.closeDate = o.CloseDate;
            oppRows.add(row);
            pipelineTotal += row.amount;
        }

        AccountDashboardDTO.DashboardResult result = new AccountDashboardDTO.DashboardResult();
        result.account = summary;
        result.contacts = contactRows;
        result.opportunities = oppRows;
        result.pipelineTotal = pipelineTotal;
        return result;
    }

    public static List<String> getOpportunityStageNames() {
        List<String> values = new List<String>();
        for (Schema.PicklistEntry entry : Opportunity.StageName.getDescribe().getPicklistValues()) {
            if (entry.isActive()) {
                values.add(entry.getValue());
            }
        }
        return values;
    }

    public static void updateOpportunityStage(Id opportunityId, String newStageName) {
        if (opportunityId == null || String.isBlank(newStageName)) {
            throw new DashboardException('An Opportunity and a Stage are required.');
        }
        try {
            OpportunitySelector.updateStage(opportunityId, newStageName);
        } catch (OpportunitySelector.InvalidStageException e) {
            throw new DashboardException(e.getMessage());
        } catch (DmlException e) {
            throw new DashboardException('The Opportunity Stage could not be updated: ' + e.getDmlMessage(0));
        }
    }
}
