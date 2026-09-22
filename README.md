# Visualforce → Aura → LWC → React: What Should Salesforce Developers Actually Learn Now?

A public Salesforce engineering experiment: the same business requirement, implemented four times, compared on equal footing, against a real Salesforce org — not a synthetic benchmark and not a conclusion decided in advance.

## 1. The question

Salesforce's UI story has gone Visualforce → Aura → Lightning Web Components → (now, officially, GA as of July 2026) React via Salesforce Multi-Framework. What should a Salesforce developer actually invest in learning today, and what do they still need to understand because it's sitting in production orgs everywhere? This repo answers that empirically instead of asserting it.

## 2. The common requirement

An **Account 360 mini-dashboard**: search/select an Account, view its details/Contacts/Opportunities, filter Opportunities by Stage, see the filtered pipeline total, update an Opportunity's Stage, with loading/empty/error states and full FLS/CRUD/sharing enforcement. Full spec: [prompts/requirement.md](prompts/requirement.md).

## 3. Architecture

One shared Apex selector/service layer (`AccountSelector`, `ContactSelector`, `OpportunitySelector`, `AccountDashboardService`) backs three of the four UIs directly; React reaches the same service through its own Apex REST endpoint because Multi-Framework apps cannot call `@AuraEnabled`/`@wire` at all. Full write-up, including live-verified current documentation for all four technologies: [docs/architecture.md](docs/architecture.md).

## 4. Visualforce implementation

[force-app/main/default/pages/AccountDashboard.page](force-app/main/default/pages/AccountDashboard.page) + [VisualforceAccountDashboardController.cls](force-app/main/default/classes/VisualforceAccountDashboardController.cls). Server-driven, no client-side JS framework; verified live in the org.

## 5. Aura implementation

[force-app/main/default/aura/accountDashboard](force-app/main/default/aura/accountDashboard) (component + controller + helper), launched via a thin [accountDashboardApp.app](force-app/main/default/aura/accountDashboardApp/accountDashboardApp.app) for direct access; shares its Apex controller with LWC. Verified live in the org.

## 6. LWC implementation

[force-app/main/default/lwc/accountDashboardLwc](force-app/main/default/lwc/accountDashboardLwc). Uses Lightning Data Service for the Opportunity Stage update and imperative Apex for the composite dashboard read. 6 Jest tests. Verified live in the org (previewed via a thin Aura host, since LWC has no standalone-URL launcher).

## 7. React implementation (Salesforce Multi-Framework)

[force-app/main/default/uiBundles/AccountDashboardReact](force-app/main/default/uiBundles/AccountDashboardReact), scaffolded with `sf template generate ui-bundle --template reactbasic` and deployed as a `UIBundle` + `CustomApplication`. Reads/writes through a dedicated Apex REST endpoint via `dataSdk.fetch()`. 5 Vitest tests, production build verified. Its live browser/data round trip was **not** fully completed in this session due to two real, documented tooling gaps (a local dev-proxy auth issue and an App Launcher visibility issue) — see [results/ai-experiment-log.md](results/ai-experiment-log.md) for the exact diagnosis.

## 8. Testing

Equivalent acceptance scenarios across all four (Account with/without Contacts/Opportunities, filtering, Stage update, permission failure, server error, empty search, large dataset) implemented as Apex tests (39 methods, all passing against the real org), LWC Jest tests (6), and React Vitest tests (5). Matrix: [prompts/requirement.md](prompts/requirement.md#acceptance-test-matrix-equivalent-across-all-four-implementations).

## 9. Comparison

Raw, measured counts (files, lines, test counts, real errors hit): [results/comparison.md](results/comparison.md). Narrative comparison across data-access, state-management, testing, debugging, tooling, App Builder integration, portability, and learning curve: [docs/comparison.md](docs/comparison.md).

## 10. AI coding-agent findings

Every mistake the AI coding agent made while building this — including ones a test suite didn't catch — is logged without editing for appearances: [results/ai-experiment-log.md](results/ai-experiment-log.md). Highlights: a real Visualforce EL-binding gotcha, a picklist-validation assumption that was wrong for this org, an LWC bug that shipped past 100%-passing Jest tests and was only caught by live browser testing, and a chain of npm/tooling issues specific to the React path.

## 11. What developers should learn today

Full reasoning: [docs/findings.md](docs/findings.md). Short version: LWC remains the right default for anything living inside Lightning pages; React via Multi-Framework is a real, current option for standalone/portable apps once a team accepts its different (npm/tooling-shaped) risk profile; Aura and Visualforce are not going away from existing orgs and still need to be understood, even though neither is where new development should start.

## 12. Known limitations

- React's live data round trip in a browser was not completed in this session (backend independently verified via unit tests instead) — see Finding 4 in [docs/findings.md](docs/findings.md).
- No performance benchmarks are claimed anywhere in this repository.
- One org, one AI agent, one moderately-sized feature — a controlled comparison, not a statistical sample.
- All code here was written by an AI coding agent and should be reviewed like any AI-generated code before being treated as production-ready.

## 13. Sources

All Multi-Framework/React claims were verified against live `developer.salesforce.com/docs/platform/multiframework/` documentation fetched during this project (not training-time memory) — full citation list in [docs/architecture.md](docs/architecture.md#4-per-framework-research-summary). Salesforce CLI behavior, Apex governor-limit behavior, and every deploy/test result cited were reproduced directly against org `orgfarm-c0edc8e06c-dev-ed`.

---

## Repository structure

```
salesforce-frontend-evolution/
├── README.md                    - this file
├── docs/
│   ├── architecture.md          - research findings + shared architecture
│   ├── comparison.md            - narrative comparison
│   └── findings.md              - factual findings report
├── force-app/main/default/
│   ├── classes/                 - shared Apex (selectors, service, DTO, per-UI controllers, tests)
│   ├── pages/                   - Visualforce
│   ├── aura/                    - Aura component + launcher app + LWC preview host
│   ├── lwc/                     - LWC
│   ├── uiBundles/               - React (Salesforce Multi-Framework)
│   ├── applications/            - CustomApplication for the React UIBundle
│   └── permissionsets/          - access grant for the React app
├── prompts/
│   └── requirement.md           - the shared functional spec + acceptance test matrix
└── results/
    ├── comparison.md            - raw metrics
    └── ai-experiment-log.md     - the AI coding experiment log
```
