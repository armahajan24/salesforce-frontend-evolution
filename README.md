# Visualforce → Aura → LWC → React: What Should Salesforce Developers Actually Learn Now?

A public Salesforce engineering experiment: the same business requirement, implemented four times, compared on equal footing, against a real Salesforce org — not a synthetic benchmark and not a conclusion decided in advance.

## Quick start

Prerequisites: [Salesforce CLI](https://developer.salesforce.com/tools/salesforcecli) (`sf`), Node.js 20+/npm, and a Salesforce org on Hyperforce (Enterprise, Performance, Unlimited, Developer, or Partner Developer edition — required for the React/Multi-Framework piece; the other three work on any org).

```bash
# 1. Clone and authenticate
git clone https://github.com/armahajan24/salesforce-frontend-evolution.git
cd salesforce-frontend-evolution
sf org login web --alias myorg --set-default

# 2. Install dependencies (repo root, for Jest/Prettier tooling)
npm install

# 3. Install dependencies for the React UIBundle separately - it's its own npm project
cd force-app/main/default/uiBundles/AccountDashboardReact
npm install
npm run build   # builds dist/, which is what actually gets deployed
cd ../../../../..

# 4. Deploy everything (Apex, Visualforce, Aura, LWC, the React UIBundle,
#    its CustomApplication, and its PermissionSet) and run the Apex tests
sf project deploy start --source-dir force-app --test-level RunLocalTests

# 5. Grant yourself access to the React app (app visibility + Apex class access + API Enabled)
sf org assign permset --name AccountDashboardReactAccess

# 6. Open each implementation
sf org open --path "/apex/AccountDashboard"                 # Visualforce
sf org open --path "/c/accountDashboardApp.app"              # Aura
sf org open --path "/c/accountDashboardLwcHost.app"           # LWC (previewed via a thin Aura host)
sf org open                                                    # then use App Launcher → "Account Dashboard React"
```

Run the non-Apex test suites locally:

```bash
npm run test:unit                                                          # LWC Jest tests
cd force-app/main/default/uiBundles/AccountDashboardReact && npx vitest run # React Vitest tests
```

This repository is licensed under [MIT](LICENSE) — reuse the code freely, including in your own comparison or write-up.

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

[force-app/main/default/uiBundles/AccountDashboardReact](force-app/main/default/uiBundles/AccountDashboardReact), scaffolded with `sf template generate ui-bundle --template reactbasic` and deployed as a `UIBundle` + `CustomApplication`. Reads/writes through a dedicated Apex REST endpoint (`AccountDashboardRestResource`) via `dataSdk.fetch()` for all four operations (search, dashboard read, stage list, Stage update) — see [docs/architecture.md](docs/architecture.md) for why this app uses `dataSdk.fetch()` + Apex REST throughout rather than GraphQL. 5 Vitest tests, production build verified, and the full flow (search → select → dashboard → Contacts/Opportunities → pipeline total → Stage filter → Stage update → reload with persistence confirmed via a direct SOQL query) was **verified live against the deployed production app**. Getting there required diagnosing and fixing a real `CustomApplication`/`PermissionSet` metadata gap and scientifically isolating a local dev-proxy-only auth quirk — see [docs/findings.md](docs/findings.md) (Finding 4) and [results/ai-experiment-log.md](results/ai-experiment-log.md) for the full diagnosis.

## 8. Testing

Equivalent acceptance scenarios across all four (Account with/without Contacts/Opportunities, filtering, Stage update, permission failure, server error, empty search, large dataset) implemented as Apex tests (43 methods, all passing against the real org), LWC Jest tests (6), and React Vitest tests (5). Matrix: [prompts/requirement.md](prompts/requirement.md#acceptance-test-matrix-equivalent-across-all-four-implementations).

**The single most important test-related finding in this repo**: the LWC's `lightning-combobox` was once bound to the wrong data shape (`{id, name}` instead of the required `{label, value}`) — and all 6 Jest tests still passed, because they dispatched synthetic `change` events that never exercised the actual option-rendering path. Only live browser testing against the real org caught it. This is stronger evidence than a simple "LWC vs. React" comparison: **AI-generated code plus a fully green unit-test suite is not the same claim as "this works" — real platform verification is not optional.** Full writeup: [results/ai-experiment-log.md](results/ai-experiment-log.md), finding #9.

## 9. Comparison

Raw, measured counts (files, lines, test counts, real errors hit), with a stated, reproducible methodology and shared-backend vs. framework-specific code separated out: [results/comparison.md](results/comparison.md). Narrative comparison across data-access, state-management, testing, debugging, tooling, App Builder integration, portability, and learning curve: [docs/comparison.md](docs/comparison.md) and [docs/framework-comparison.md](docs/framework-comparison.md) (dimension-by-dimension, no overall winner assigned).

## 10. AI coding-agent findings

Every mistake the AI coding agent made while building this — including ones a test suite didn't catch — is logged without editing for appearances: [results/ai-experiment-log.md](results/ai-experiment-log.md). Highlights: a real Visualforce EL-binding gotcha, a picklist-validation assumption that was wrong for this org, an LWC bug that shipped past 100%-passing Jest tests and was only caught by live browser testing, and a chain of npm/tooling issues specific to the React path.

## 11. What developers should learn today

Full reasoning: [docs/findings.md](docs/findings.md). Short version: LWC remains the right default for anything living inside Lightning pages; React via Multi-Framework is a real, current option for standalone/portable apps once a team accepts its different (npm/tooling-shaped) risk profile; Aura and Visualforce are not going away from existing orgs and still need to be understood, even though neither is where new development should start.

## 12. Known limitations

- Stage validation (`OpportunitySelector.isActiveStage`) checks against the *org-wide* active `Opportunity.StageName` picklist values. In a real org using multiple Sales Processes/record types, valid Stages can legitimately differ by record type — this demo doesn't model that, since the requirement doesn't call for multiple sales processes.
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
├── LICENSE                      - MIT
├── docs/
│   ├── architecture.md          - research findings + shared architecture
│   ├── comparison.md            - narrative comparison
│   ├── framework-comparison.md  - fair, dimension-by-dimension architecture comparison
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
