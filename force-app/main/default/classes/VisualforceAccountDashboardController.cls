/**
 * Controller for the Visualforce Account 360 page. Every server interaction is
 * a full or partial page round trip (no client-side reactivity), so state
 * (search term, selected Account, stage filter, in-flight edit) is held on the
 * controller between requests rather than in JavaScript.
 */
public with sharing class VisualforceAccountDashboardController {
    public String searchTerm { get; set; }
    public Id selectedAccountId { get; set; }
    public String stageFilter { get; set; }
    public String errorMessage { get; private set; }

    public String editingOpportunityId { get; set; }
    public String newStageValue { get; set; }

    private AccountDashboardDTO.DashboardResult dashboard;

    public VisualforceAccountDashboardController() {
        stageFilter = 'All';
    }

    public Boolean getHasError() {
        return String.isNotBlank(errorMessage);
    }

    public Boolean getHasAccount() {
        return dashboard != null;
    }

    public AccountDashboardDTO.AccountSummary getAccountSummary() {
        return dashboard != null ? dashboard.account : null;
    }

    public List<AccountDashboardDTO.ContactRow> getContacts() {
        return dashboard != null ? dashboard.contacts : new List<AccountDashboardDTO.ContactRow>();
    }

    public Boolean getHasContacts() {
        return !getContacts().isEmpty();
    }

    public List<AccountDashboardDTO.OpportunityRow> getFilteredOpportunities() {
        List<AccountDashboardDTO.OpportunityRow> all = dashboard != null
            ? dashboard.opportunities
            : new List<AccountDashboardDTO.OpportunityRow>();
        if (String.isBlank(stageFilter) || stageFilter == 'All') {
            return all;
        }
        List<AccountDashboardDTO.OpportunityRow> filtered = new List<AccountDashboardDTO.OpportunityRow>();
        for (AccountDashboardDTO.OpportunityRow row : all) {
            if (row.stageName == stageFilter) {
                filtered.add(row);
            }
        }
        return filtered;
    }

    public Boolean getHasOpportunities() {
        return !getFilteredOpportunities().isEmpty();
    }

    public Decimal getPipelineTotal() {
        Decimal total = 0;
        for (AccountDashboardDTO.OpportunityRow row : getFilteredOpportunities()) {
            total += row.amount;
        }
        return total;
    }

    public List<SelectOption> getAccountOptions() {
        List<SelectOption> options = new List<SelectOption>();
        options.add(new SelectOption('', '-- Search results --'));
        try {
            for (AccountDashboardDTO.AccountOption opt : AccountDashboardService.searchAccounts(searchTerm)) {
                options.add(new SelectOption(opt.id, opt.name));
            }
        } catch (Exception e) {
            errorMessage = 'Unable to search Accounts right now. Please try again.';
        }
        return options;
    }

    public List<SelectOption> getStageOptions() {
        List<SelectOption> options = new List<SelectOption>();
        options.add(new SelectOption('All', 'All Stages'));
        for (String stageName : AccountDashboardService.getOpportunityStageNames()) {
            options.add(new SelectOption(stageName, stageName));
        }
        return options;
    }

    public List<SelectOption> getOpportunityOptionsForUpdate() {
        List<SelectOption> options = new List<SelectOption>();
        options.add(new SelectOption('', '-- Select an Opportunity --'));
        for (AccountDashboardDTO.OpportunityRow row : getFilteredOpportunities()) {
            options.add(new SelectOption(row.id, row.name + ' (' + row.stageName + ')'));
        }
        return options;
    }

    public PageReference doSearch() {
        errorMessage = null;
        selectedAccountId = null;
        dashboard = null;
        return null;
    }

    public PageReference selectAccount() {
        errorMessage = null;
        loadDashboard();
        return null;
    }

    public PageReference applyStageFilter() {
        return null;
    }

    public PageReference saveStageUpdate() {
        errorMessage = null;
        try {
            AccountDashboardService.updateOpportunityStage(editingOpportunityId, newStageValue);
            loadDashboard();
            editingOpportunityId = null;
            newStageValue = null;
        } catch (AccountDashboardService.DashboardException e) {
            errorMessage = e.getMessage();
        } catch (Exception e) {
            errorMessage = 'Unable to update the Opportunity Stage right now. Please try again.';
        }
        return null;
    }

    private void loadDashboard() {
        try {
            dashboard = AccountDashboardService.getDashboard(selectedAccountId);
        } catch (AccountDashboardService.DashboardException e) {
            errorMessage = e.getMessage();
            dashboard = null;
        } catch (Exception e) {
            errorMessage = 'Unable to load the Account dashboard right now. Please try again.';
            dashboard = null;
        }
    }
}
