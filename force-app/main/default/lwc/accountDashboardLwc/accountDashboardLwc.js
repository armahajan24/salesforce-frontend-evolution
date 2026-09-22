import { LightningElement } from "lwc";
import { updateRecord } from "lightning/uiRecordApi";
import OPPORTUNITY_ID_FIELD from "@salesforce/schema/Opportunity.Id";
import STAGE_FIELD from "@salesforce/schema/Opportunity.StageName";
import searchAccounts from "@salesforce/apex/AccountDashboardController.searchAccounts";
import getDashboard from "@salesforce/apex/AccountDashboardController.getDashboard";
import getOpportunityStages from "@salesforce/apex/AccountDashboardController.getOpportunityStages";

/**
 * LWC implementation of the Account 360 dashboard.
 *
 * The composite dashboard read (Account + Contacts + Opportunities + pipeline
 * total) is imperative Apex, deliberately: it avoids three separate @wire round
 * trips and lets the server enforce FLS/CRUD and bulkification in one place.
 * The Opportunity Stage update, however, goes through Lightning Data Service
 * (lightning/uiRecordApi.updateRecord) rather than Apex - the textbook case LDS
 * exists for. This means the Stage update inherits Salesforce's own DML
 * validation/cache consistency instead of this app's custom "not a valid
 * Stage" guard in OpportunitySelector - documented as a deliberate, real
 * difference from the other three implementations, not an inconsistency.
 */
export default class AccountDashboardLwc extends LightningElement {
    searchTerm = "";
    accountOptions = [];
    searchAttempted = false;
    selectedAccountId = "";

    dashboard;
    stageOptions = [];
    stageFilter = "All";

    editingOpportunityId = "";
    newStageValue = "";

    isLoading = false;
    errorMessage = "";

    connectedCallback() {
        getOpportunityStages()
            .then((stages) => {
                this.stageOptions = stages;
            })
            .catch(() => {
                // Non-fatal: only the "New Stage" picker is affected.
            });
    }

    get hasError() {
        return !!this.errorMessage;
    }

    get hasAccountOptions() {
        return this.accountOptions.length > 0;
    }

    get accountComboboxOptions() {
        return this.accountOptions.map((opt) => ({ label: opt.name, value: opt.id }));
    }

    get showNoAccountResults() {
        return this.searchAttempted && !this.hasAccountOptions;
    }

    get hasDashboard() {
        return !!this.dashboard;
    }

    get hasContacts() {
        return this.hasDashboard && this.dashboard.contacts.length > 0;
    }

    get filteredOpportunities() {
        if (!this.hasDashboard) {
            return [];
        }
        const all = this.dashboard.opportunities;
        return this.stageFilter === "All"
            ? all
            : all.filter((row) => row.stageName === this.stageFilter);
    }

    get hasOpportunities() {
        return this.filteredOpportunities.length > 0;
    }

    get pipelineTotal() {
        return this.filteredOpportunities.reduce((sum, row) => sum + (row.amount || 0), 0);
    }

    get stageFilterOptions() {
        return [{ label: "All Stages", value: "All" }, ...this.stageOptions.map((s) => ({ label: s, value: s }))];
    }

    get stagePickerOptions() {
        return this.stageOptions.map((s) => ({ label: s, value: s }));
    }

    get opportunityPickerOptions() {
        return this.filteredOpportunities.map((row) => ({
            label: `${row.name} (${row.stageName})`,
            value: row.id
        }));
    }

    handleSearchTermChange(event) {
        this.searchTerm = event.target.value;
    }

    handleSearch() {
        this.isLoading = true;
        this.errorMessage = "";
        searchAccounts({ searchTerm: this.searchTerm })
            .then((options) => {
                this.accountOptions = options;
                this.searchAttempted = true;
                this.selectedAccountId = "";
                this.dashboard = undefined;
            })
            .catch((error) => {
                this.errorMessage = this.extractError(error);
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    handleAccountSelect(event) {
        this.selectedAccountId = event.detail.value;
        this.loadDashboard();
    }

    loadDashboard() {
        if (!this.selectedAccountId) {
            return;
        }
        this.isLoading = true;
        this.errorMessage = "";
        getDashboard({ accountId: this.selectedAccountId })
            .then((result) => {
                this.dashboard = result;
                this.stageFilter = "All";
            })
            .catch((error) => {
                this.dashboard = undefined;
                this.errorMessage = this.extractError(error);
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    handleStageFilterChange(event) {
        this.stageFilter = event.detail.value;
    }

    handleEditingOppChange(event) {
        this.editingOpportunityId = event.detail.value;
    }

    handleNewStageChange(event) {
        this.newStageValue = event.detail.value;
    }

    handleUpdateStage() {
        if (!this.editingOpportunityId || !this.newStageValue) {
            this.errorMessage = "Select an Opportunity and a Stage before updating.";
            return;
        }
        this.isLoading = true;
        this.errorMessage = "";

        const fields = {};
        fields[OPPORTUNITY_ID_FIELD.fieldApiName] = this.editingOpportunityId;
        fields[STAGE_FIELD.fieldApiName] = this.newStageValue;

        updateRecord({ fields })
            .then(() => {
                this.editingOpportunityId = "";
                this.newStageValue = "";
                this.loadDashboard();
            })
            .catch((error) => {
                this.isLoading = false;
                this.errorMessage = this.extractError(error);
            });
    }

    extractError(error) {
        if (error && error.body) {
            if (Array.isArray(error.body)) {
                return error.body.map((e) => e.message).join(", ");
            }
            if (error.body.message) {
                return error.body.message;
            }
            if (error.body.output && error.body.output.errors) {
                return error.body.output.errors.map((e) => e.message).join(", ");
            }
        }
        return "An unexpected error occurred. Please try again.";
    }
}
