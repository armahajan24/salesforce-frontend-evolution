import { createElement } from "lwc";
import AccountDashboardLwc from "c/accountDashboardLwc";
import searchAccounts from "@salesforce/apex/AccountDashboardController.searchAccounts";
import getDashboard from "@salesforce/apex/AccountDashboardController.getDashboard";
import getOpportunityStages from "@salesforce/apex/AccountDashboardController.getOpportunityStages";
import { updateRecord } from "lightning/uiRecordApi";

jest.mock(
    "@salesforce/apex/AccountDashboardController.searchAccounts",
    () => ({ default: jest.fn() }),
    { virtual: true }
);
jest.mock(
    "@salesforce/apex/AccountDashboardController.getDashboard",
    () => ({ default: jest.fn() }),
    { virtual: true }
);
jest.mock(
    "@salesforce/apex/AccountDashboardController.getOpportunityStages",
    () => ({ default: jest.fn() }),
    { virtual: true }
);
jest.mock("lightning/uiRecordApi", () => ({ updateRecord: jest.fn() }), { virtual: true });

const DASHBOARD_RESULT = {
    account: {
        id: "001000000000001",
        name: "Acme Rockets",
        industry: "Technology",
        phone: "415-555-0100",
        ownerName: "Jane Owner",
        billingCity: "San Francisco",
        billingState: "CA"
    },
    contacts: [{ id: "003000000000001", name: "Jane Doe", title: "CTO", email: "jane@example.com", phone: "415-555-0200" }],
    opportunities: [
        { id: "006000000000001", name: "Deal A", stageName: "Prospecting", amount: 1000, closeDate: "2026-12-01" },
        { id: "006000000000002", name: "Deal B", stageName: "Closed Won", amount: 5000, closeDate: "2026-11-01" }
    ],
    pipelineTotal: 6000
};

function flushPromises() {
    return new Promise((resolve) => setTimeout(resolve, 0));
}

describe("c-account-dashboard-lwc", () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    it("renders an empty state with no search results initially", () => {
        getOpportunityStages.mockResolvedValue(["Prospecting", "Closed Won"]);
        const element = createElement("c-account-dashboard-lwc", { is: AccountDashboardLwc });
        document.body.appendChild(element);

        const combobox = element.shadowRoot.querySelector("lightning-combobox");
        expect(combobox).toBeNull();
    });

    it("shows a no-results message when a search returns nothing", async () => {
        getOpportunityStages.mockResolvedValue([]);
        searchAccounts.mockResolvedValue([]);

        const element = createElement("c-account-dashboard-lwc", { is: AccountDashboardLwc });
        document.body.appendChild(element);

        element.shadowRoot.querySelector("lightning-button").click();
        await flushPromises();

        const message = element.shadowRoot.textContent;
        expect(message).toContain("No matching Accounts");
    });

    it("loads and displays the dashboard for a selected Account", async () => {
        getOpportunityStages.mockResolvedValue(["Prospecting", "Closed Won"]);
        searchAccounts.mockResolvedValue([{ id: "001000000000001", name: "Acme Rockets" }]);
        getDashboard.mockResolvedValue(DASHBOARD_RESULT);

        const element = createElement("c-account-dashboard-lwc", { is: AccountDashboardLwc });
        document.body.appendChild(element);

        element.shadowRoot.querySelector("lightning-button").click();
        await flushPromises();

        const accountCombobox = element.shadowRoot.querySelector("lightning-combobox");
        accountCombobox.dispatchEvent(new CustomEvent("change", { detail: { value: "001000000000001" } }));
        await flushPromises();

        expect(getDashboard).toHaveBeenCalledWith({ accountId: "001000000000001" });
        expect(element.shadowRoot.textContent).toContain("Acme Rockets");
        expect(element.shadowRoot.textContent).toContain("Jane Doe");
        expect(element.shadowRoot.textContent).toContain("Total Pipeline (filtered): 6000");
    });

    it("filters Opportunities by Stage and recalculates the pipeline total", async () => {
        getOpportunityStages.mockResolvedValue(["Prospecting", "Closed Won"]);
        searchAccounts.mockResolvedValue([{ id: "001000000000001", name: "Acme Rockets" }]);
        getDashboard.mockResolvedValue(DASHBOARD_RESULT);

        const element = createElement("c-account-dashboard-lwc", { is: AccountDashboardLwc });
        document.body.appendChild(element);

        element.shadowRoot.querySelector("lightning-button").click();
        await flushPromises();
        element.shadowRoot
            .querySelector("lightning-combobox")
            .dispatchEvent(new CustomEvent("change", { detail: { value: "001000000000001" } }));
        await flushPromises();

        // index 0 is the "Select an Account" combobox, which stays rendered
        // after the dashboard loads; index 1 is the Stage filter.
        const stageFilterCombobox = element.shadowRoot.querySelectorAll("lightning-combobox")[1];
        stageFilterCombobox.dispatchEvent(new CustomEvent("change", { detail: { value: "Prospecting" } }));
        await flushPromises();

        expect(element.shadowRoot.textContent).toContain("Total Pipeline (filtered): 1000");
        expect(element.shadowRoot.textContent).not.toContain("Deal B");
    });

    it("shows a safe error message when the dashboard fails to load", async () => {
        getOpportunityStages.mockResolvedValue([]);
        searchAccounts.mockResolvedValue([{ id: "001000000000001", name: "Acme Rockets" }]);
        getDashboard.mockRejectedValue({ body: { message: "The selected Account could not be found or is not accessible." } });

        const element = createElement("c-account-dashboard-lwc", { is: AccountDashboardLwc });
        document.body.appendChild(element);

        element.shadowRoot.querySelector("lightning-button").click();
        await flushPromises();
        element.shadowRoot
            .querySelector("lightning-combobox")
            .dispatchEvent(new CustomEvent("change", { detail: { value: "001000000000001" } }));
        await flushPromises();

        expect(element.shadowRoot.textContent).toContain("could not be found or is not accessible");
    });

    it("updates the Opportunity Stage via Lightning Data Service", async () => {
        getOpportunityStages.mockResolvedValue(["Prospecting", "Closed Won"]);
        searchAccounts.mockResolvedValue([{ id: "001000000000001", name: "Acme Rockets" }]);
        getDashboard.mockResolvedValue(DASHBOARD_RESULT);
        updateRecord.mockResolvedValue({});

        const element = createElement("c-account-dashboard-lwc", { is: AccountDashboardLwc });
        document.body.appendChild(element);

        element.shadowRoot.querySelector("lightning-button").click();
        await flushPromises();
        element.shadowRoot
            .querySelector("lightning-combobox")
            .dispatchEvent(new CustomEvent("change", { detail: { value: "001000000000001" } }));
        await flushPromises();

        // index 0 = Select an Account, 1 = Stage filter, 2 = Opportunity picker, 3 = New Stage.
        const comboboxes = element.shadowRoot.querySelectorAll("lightning-combobox");
        const opportunityPicker = comboboxes[2];
        const stagePicker = comboboxes[3];
        opportunityPicker.dispatchEvent(new CustomEvent("change", { detail: { value: "006000000000001" } }));
        stagePicker.dispatchEvent(new CustomEvent("change", { detail: { value: "Closed Won" } }));

        const buttons = element.shadowRoot.querySelectorAll("lightning-button");
        buttons[buttons.length - 1].click();
        await flushPromises();

        expect(updateRecord).toHaveBeenCalled();
    });
});
