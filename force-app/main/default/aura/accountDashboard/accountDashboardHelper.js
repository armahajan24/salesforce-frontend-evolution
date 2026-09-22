({
    loadStageOptions: function (component) {
        var action = component.get("c.getOpportunityStages");
        action.setCallback(this, function (response) {
            if (response.getState() === "SUCCESS") {
                component.set("v.stageOptions", response.getReturnValue());
            }
            // A failure here is non-fatal (only the "New Stage" picker is affected);
            // deliberately not surfaced as a page-level error.
        });
        $A.enqueueAction(action);
    },

    searchAccounts: function (component) {
        var searchTerm = component.get("v.searchTerm");
        this.setLoading(component, true);
        this.clearError(component);

        var action = component.get("c.searchAccounts");
        action.setParams({ searchTerm: searchTerm });
        action.setCallback(this, function (response) {
            this.setLoading(component, false);
            component.set("v.searchAttempted", true);
            if (response.getState() === "SUCCESS") {
                var options = response.getReturnValue();
                component.set("v.accountOptions", options);
                component.set("v.hasAccountOptions", options.length > 0);
                component.set("v.selectedAccountId", "");
                component.set("v.dashboard", null);
                component.set("v.hasDashboard", false);
            } else {
                this.setError(component, this.extractError(response));
            }
        });
        $A.enqueueAction(action);
    },

    loadDashboard: function (component, accountId) {
        this.setLoading(component, true);
        this.clearError(component);

        var action = component.get("c.getDashboard");
        action.setParams({ accountId: accountId });
        action.setCallback(this, function (response) {
            this.setLoading(component, false);
            if (response.getState() === "SUCCESS") {
                var dashboard = response.getReturnValue();
                component.set("v.dashboard", dashboard);
                component.set("v.hasDashboard", true);
                component.set("v.hasContacts", dashboard.contacts && dashboard.contacts.length > 0);
                component.set("v.stageFilter", "All");
                this.recomputeFilteredOpportunities(component);
            } else {
                component.set("v.dashboard", null);
                component.set("v.hasDashboard", false);
                this.setError(component, this.extractError(response));
            }
        });
        $A.enqueueAction(action);
    },

    applyStageFilter: function (component) {
        this.recomputeFilteredOpportunities(component);
    },

    recomputeFilteredOpportunities: function (component) {
        var dashboard = component.get("v.dashboard");
        var stageFilter = component.get("v.stageFilter");
        var all = (dashboard && dashboard.opportunities) ? dashboard.opportunities : [];
        var filtered = (!stageFilter || stageFilter === "All")
            ? all
            : all.filter(function (row) { return row.stageName === stageFilter; });

        var total = filtered.reduce(function (sum, row) { return sum + (row.amount || 0); }, 0);

        component.set("v.filteredOpportunities", filtered);
        component.set("v.hasOpportunities", filtered.length > 0);
        component.set("v.pipelineTotal", total);
    },

    updateOpportunityStage: function (component) {
        var opportunityId = component.get("v.editingOpportunityId");
        var newStageValue = component.get("v.newStageValue");
        if (!opportunityId || !newStageValue) {
            this.setError(component, "Select an Opportunity and a Stage before updating.");
            return;
        }

        this.setLoading(component, true);
        this.clearError(component);

        var action = component.get("c.updateOpportunityStage");
        action.setParams({ opportunityId: opportunityId, newStageName: newStageValue });
        var accountId = component.get("v.selectedAccountId");
        action.setCallback(this, function (response) {
            if (response.getState() === "SUCCESS") {
                component.set("v.editingOpportunityId", "");
                component.set("v.newStageValue", "");
                this.loadDashboard(component, accountId); // also clears isLoading
            } else {
                this.setLoading(component, false);
                this.setError(component, this.extractError(response));
            }
        });
        $A.enqueueAction(action);
    },

    setLoading: function (component, isLoading) {
        component.set("v.isLoading", isLoading);
    },

    setError: function (component, message) {
        component.set("v.hasError", true);
        component.set("v.errorMessage", message);
    },

    clearError: function (component) {
        component.set("v.hasError", false);
        component.set("v.errorMessage", "");
    },

    extractError: function (response) {
        var errors = response.getError();
        if (errors && errors[0] && errors[0].message) {
            return errors[0].message;
        }
        return "An unexpected error occurred. Please try again.";
    }
})
