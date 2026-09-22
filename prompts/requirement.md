# Common Requirement — Account 360 Mini-Dashboard

This is the single functional spec implemented four times (Visualforce, Aura, LWC, React/Multi-Framework), verbatim-equivalent across all four.

## Functional requirements

1. Search/select an Account (typeahead by Name).
2. Display Account details (Name, Industry, Phone, Owner, Billing City/State).
3. Display related Contacts (Name, Title, Email, Phone) for the selected Account.
4. Display related Opportunities (Name, Stage, Amount, Close Date) for the selected Account.
5. Filter the Opportunities list by Stage (client-side filter on already-fetched data — no extra server round trip per filter change).
6. Display total pipeline value (sum of `Amount`) of the *currently filtered* Opportunity set.
7. Allow the user to update an Opportunity's Stage inline from the dashboard, with the pipeline total and list re-rendering after a successful update.
8. Show a loading state while the Account/Contacts/Opportunities are being fetched, and while a Stage update is in flight.
9. Show an empty state when the Account has no Contacts and/or no Opportunities, and when a search returns no matching Accounts.
10. Show a meaningful, non-leaking error message on server/data errors (e.g., DML failure, network failure) — no raw stack traces or Apex exception internals surfaced to the user.
11. Respect Salesforce security throughout: sharing rules (`with sharing`), object/field-level CRUD and FLS, no SOQL/SOSL injection, bulk-safe (no per-row SOQL/DML in a loop).

## Out of scope (kept equal across all four, not added to any one)

- Creating/deleting Accounts, Contacts, or Opportunities.
- Editing any field other than Opportunity Stage.
- Pagination beyond a sane row cap (200 rows) — documented as a shared, equal limitation.
- Real-time/streaming updates (Platform Events, CDC) — not required by the spec.

## Acceptance test matrix (equivalent across all four implementations)

| # | Scenario |
|---|---|
| 1 | Account with both Contacts and Opportunities loads and displays correctly |
| 2 | Account with no Contacts shows Contacts empty state |
| 3 | Account with no Opportunities shows Opportunities empty state |
| 4 | Filtering Opportunities by Stage narrows the list and updates the pipeline total |
| 5 | Updating an Opportunity's Stage succeeds and the UI reflects it without a full page reload |
| 6 | A user lacking FLS/CRUD access on a required field/object gets a clear, safe error, not a crash |
| 7 | A simulated server/data error (e.g., DML exception) is shown as a meaningful message |
| 8 | Empty search (no accounts match) shows a "no results" state, not an error |
| 9 | Large-enough related-record set (~150+ Opportunities on one Account) does not break governor limits, pagination, or the UI |

See [tests/](../tests/) for the concrete test implementations per framework and [results/comparison.md](../results/comparison.md) for outcomes.
