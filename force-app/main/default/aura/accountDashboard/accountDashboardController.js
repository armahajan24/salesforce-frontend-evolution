({
    doInit: function (component, event, helper) {
        helper.loadStageOptions(component);
    },

    handleSearch: function (component, event, helper) {
        helper.searchAccounts(component);
    },

    handleAccountSelect: function (component, event, helper) {
        var accountId = component.get("v.selectedAccountId");
        if (accountId) {
            helper.loadDashboard(component, accountId);
        }
    },

    handleStageFilterChange: function (component, event, helper) {
        helper.applyStageFilter(component);
    },

    handleEditingOppChange: function (component, event, helper) {
        // value binding on the <lightning:select> already updates v.editingOpportunityId
    },

    handleNewStageChange: function (component, event, helper) {
        // value binding on the <lightning:select> already updates v.newStageValue
    },

    handleUpdateStage: function (component, event, helper) {
        helper.updateOpportunityStage(component);
    }
})
