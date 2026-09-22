# Architecture & Research Findings — Phase 1

> Research date: 2026-09-21. Target org: `orgfarm-c0edc8e06c-dev-ed` (alias `LinkedinOrg`), Developer Edition, instance `CAN96`, confirmed Hyperforce-hosted, API v67.0.

## 1. The question

*Visualforce → Aura → LWC → React: what should Salesforce developers actually learn now?*

We answer this empirically by building the **same** Account 360 mini-dashboard four times and comparing the implementations on equal footing — not by asserting a conclusion up front. See [findings.md](findings.md) (written in Phase 10) for the answer.

## 2. Common requirement

**Account 360 mini-dashboard**: search/select an Account → show Account details, related Contacts, related Opportunities → filter Opportunities by Stage → show total pipeline value of the filtered set → update an Opportunity's Stage inline → loading/empty/error states → respect FLS/CRUD/sharing throughout.

Full spec: [prompts/requirement.md](../prompts/requirement.md).

## 3. Conceptual architecture (shared across all four UIs)

```
UI (Visualforce page / Aura cmp / LWC / React component)
        │
        ▼
Entry point (VF controller · shared @AuraEnabled AccountDashboardController · React's AccountDashboardRestResource, via dataSdk.fetch())
        │
        ▼
Service layer (Apex: AccountDashboardService) — same class, called by all four entry points
        │
        ▼
Selector layer (Apex: AccountSelector, ContactSelector, OpportunitySelector)
        │
        ▼
Salesforce data (Account, Contact, Opportunity)
```

All four UIs ultimately run the same Apex service/selector logic; only the *entry point* (the calling convention reaching that logic) differs. React's entry point happens to be Apex REST instead of `@AuraEnabled`, not a native-platform-only, Apex-free path — GraphQL/UI API were considered as an Apex-free alternative for React (see §4.4) but weren't used in this implementation.

- **Visualforce and Aura** have no native alternative to Apex for cross-object dashboard queries, so both go through the same `AccountDashboardService` + selector classes (`with sharing`, enforces CRUD/FLS via `Security.stripInaccessible` and `WITH SECURITY_ENFORCED` / `WITH USER_MODE` SOQL).
- **LWC** uses the same Apex service for the aggregate dashboard read (bulk Contacts+Opportunities in one round trip), because Lightning Data Service and the UI API `@wire` adapters are record-shaped, not "give me a dashboard" shaped — imperative Apex is the more appropriate tool here (per the requirement: "do not force Apex where native platform data APIs are clearly more appropriate," and the reverse: don't avoid Apex where it's clearly appropriate). The Opportunity Stage update, however, uses `lightning/uiRecordApi.updateRecord` (Lightning Data Service) directly — no Apex needed for a single-record field update, which is the textbook case LDS exists for.
- **React (Multi-Framework)** *cannot* call the same `@AuraEnabled` Apex methods the other three use — this is a hard platform boundary, not a design choice (see §4.4). It reads/writes data exclusively through the **Data SDK** (`@salesforce/platform-sdk`), and in this implementation every operation (Account search, dashboard read, Stage-picklist lookup, Stage update) goes through `dataSdk.fetch()` against a dedicated **Apex REST** (`@RestResource`) class, `AccountDashboardRestResource`. Salesforce's documented preference is GraphQL (`dataSdk.graphql`) for straightforward record data, with `dataSdk.fetch()` + Apex REST as the explicitly-supported path for custom server logic GraphQL doesn't cover — we chose the Apex REST path for *all* operations here (not just as a fallback) because the dashboard's composite, multi-object read shape (Account + Contacts + Opportunities + a computed pipeline total in one response) is exactly that kind of custom logic, and using one consistent transport keeps the four operations symmetric. `AccountDashboardRestResource` reuses the same selector/service *logic* (bulkification, FLS/CRUD enforcement) as the other three UIs — only the transport differs. See §4.4 for the full reasoning and docs/findings.md for the precise, corrected distinction between "React can't use `@salesforce/apex`/`@wire`" and "React can't run custom Apex" (the latter is false).

This asymmetry is itself one of the most important, concrete findings of the experiment and is documented explicitly rather than smoothed over.

## 4. Per-framework research summary

### 4.1 Visualforce — mature, in maintenance, fully supported

- Still a fully supported, production metadata type (`ApexPage`); no deprecation notice from Salesforce.
- Current-pattern guidance used here: a **plain custom controller** (`controller="VisualforceAccountDashboardController"`, no `standardController`/extension — the dashboard isn't backed by a single record, so there's no natural standard controller to extend), `@AuraEnabled`-free plain Apex methods invoked via `apex:commandButton`/`apex:actionSupport`, hand-built SLDS `<table>` markup driven by `apex:repeat` (not `apex:pageBlockTable`, which requires the classic `apex:pageBlock`/`apex:pageBlockSection` chrome this SLDS-only page deliberately doesn't use), `apex:outputPanel` for loading/empty state toggling via boolean getters, and `apex:pageMessages` for error display.
- No client-side reactivity: every "loading" or "filter changed" state is a full or partial server round-trip via `apex:commandButton`/`apex:actionSupport`'s own `reRender` targeting, with `apex:actionStatus` showing the in-flight indicator — i.e., view-state ping-pong. No `apex:actionRegion` is used (`actionSupport`'s `reRender` attribute is sufficient here). This is the central developer-experience cost we document.
- Security: relies entirely on the controller being written correctly (`with sharing`, explicit FLS checks via the shared `WITH USER_MODE` selectors) — Visualforce does not give you FLS enforcement for free the way UI API-backed components do.

### 4.2 Aura — supported, Salesforce recommends new dev in LWC, coexists with LWC

- Aura Components are still supported and can be deployed and mixed with LWC (`lightning:isUrlAddressable`, LWC-in-Aura wrapping) — Salesforce's own documentation directs new development to LWC while keeping Aura fully supported for existing code.
- Current pattern used here: `.cmp` markup + client-side controller/helper split, `component.set/get`, `aura:attribute`, `aura:handler` for events, an Apex controller shared in spirit with the VF one (separate class to keep each implementation self-contained per the "equivalent, not shared" fairness rule, but built from the same selector classes).
- Loading/error state is manual (`aura:if` on a spinner attribute you toggle yourself around every server call) — more boilerplate than LWC's `@wire` but with real client-side reactivity, unlike Visualforce.

### 4.3 LWC — the current native, standards-based Salesforce framework

- Standard Web Components (ES2022 classes, Shadow DOM, native `import`) plus Salesforce-specific decorators (`@api`, `@track`, `@wire`).
- Prefer native platform data APIs per the requirement: Opportunity Stage update via `lightning/uiRecordApi.updateRecord` (Lightning Data Service — handles cache consistency, optimistic UI, and FLS automatically); Account search via `lightning-record-picker`/`lightning-input` + a light Apex lookup (object search has no polished LDS equivalent for typeahead).
- Apex is used, deliberately, for the composite dashboard read (Account + Contacts + Opportunities + pipeline total in one call) because that avoids 3 separate wire round trips and lets us enforce FLS/CRUD and bulkify in one governed place — this is the "use Apex only where justified" case.
- GraphQL wire adapter (`lightning/uiGraphQLApi`) is current and documented but was not required here since the imperative Apex path already satisfies bulkification/limits concerns better for this multi-object shape; noted as an alternative in the LWC doc.
- Jest (`@salesforce/sfdx-lwc-jest`) is the standard, current unit-test tool — already wired into this repo's `package.json`.

### 4.4 React — Salesforce Multi-Framework (GA as of July 2026)

This is the technology most likely to be misremembered, so every claim below is sourced directly from the current `developer.salesforce.com/docs/platform/multiframework/` docs (fetched 2026-09-21), not from training-time memory.

**Status**: General Availability. Announced in open beta at TDX 2026 (April 2026); GA announced July 2026. UI Embedding (running a Multi-Framework app *inside* a Lightning page as a microfrontend, rather than as its own app) remains **Beta**.

**Availability**: Enterprise, Performance, Unlimited, Developer, and Partner Developer editions, **Hyperforce only** (not available on Alibaba Cloud or Government Cloud). Confirmed our target org qualifies (Developer Edition, instance `CAN96`, Hyperforce).

**What it is**: a framework-agnostic runtime ("Salesforce Multi-Framework") that runs a standard React (or Angular) app as first-class Salesforce metadata called a **UIBundle**, deployed via the ordinary Salesforce CLI/DX workflow, and served from a dedicated `*.my.salesforce.app` domain with browser-native isolation — not React embedded in a Visualforce/static-resource hack, and not an unofficial pattern.

**Two app types**:
- *Internal apps* (`reactinternalapp`/`reactbasic` templates): employees sign in with Salesforce credentials; app appears in the App Launcher and Salesforce mobile app; requires `CustomApplication` metadata referencing the `UIBundle`.
- *External apps* (`reactexternalapp`): customers/partners via an Experience Cloud site; requires Digital Experiences enabled plus `DigitalExperience`/`DigitalExperienceConfig`/`Network`/`CustomSite` metadata.

We build the **internal** variant, matching the other three (all internal/employee-facing).

**Project structure**: `force-app/main/default/uiBundles/<AppName>/` containing `<AppName>.uibundle-meta.xml`, `ui-bundle.json` (routing/build-output config), its own `package.json`, and standard Vite-based React source (`src/`). Scaffolded via `sf template generate ui-bundle --name <Name> --template reactbasic` (confirmed available locally through the `ui-bundle-dev` CLI plugin) or `sf template generate project --template reactinternalapp` for a full new project.

**Data access — the critical, hard constraint**: Multi-Framework apps run as standard web apps outside the LWC/Aura runtime, so none of the following are available: `@salesforce/apex/*` imports (the LWC-style `@salesforce/apex/Class.method` invocation), `@salesforce/schema/*`, `@salesforce/user/*`, `lightning/uiRecordApi`, `lightning/*` base components, or `@wire`. Instead:
- Data access goes through `@salesforce/platform-sdk`'s `createDataSDK()` → `dataSdk.graphql.query()` / `.mutate()` against the `uiapi` GraphQL schema — Salesforce's documented preferred path for straightforward record data (cached, reactive `subscribe()`/`refresh()`), **or**
- `dataSdk.fetch()` against a REST endpoint — explicitly documented as the way to reach **Apex REST** (`/services/apexrest/...`) and other `/services/data/v{version}/...` endpoints for logic GraphQL/UI API doesn't cleanly cover.
- **This implementation uses `dataSdk.fetch()` + Apex REST for all four operations** (search, composite dashboard read, Stage-picklist lookup, Stage update), not GraphQL — a deliberate choice, not a fallback used only where forced. The dashboard's shape (Account + Contacts + Opportunities + a server-computed pipeline total, in one response) is exactly the kind of custom, multi-object logic the docs point at Apex REST for, and hand-authoring the equivalent UI API GraphQL query without live schema introspection carried real hallucination risk that a single, already-tested Apex REST class avoided. GraphQL remains a valid, arguably more idiomatic alternative for a future iteration — see `docs/findings.md` for the explicit trade-off discussion.
- There is **no direct invocation of `@AuraEnabled` Apex methods, no `@wire`, and no Lightning base components** from a React Multi-Framework app — but custom Apex logic itself is fully reachable via `@RestResource` (Apex REST). "React can't call Apex" is imprecise; see `docs/findings.md`'s "Apex access, precisely" section for the corrected, exact distinction.
- Styling uses SLDS via the platform's own styling guide (not Aura/LWC's `lightning-*` base components, which aren't available).

**Testing**: standard web tooling, not Salesforce-specific — Vitest + Testing Library (jsdom) for unit tests, Playwright for E2E, run from inside the UIBundle directory (`npm run test`, `npm run build:e2e && npx playwright test`). No Jest/`sfdx-lwc-jest`, no Apex test dependency for the React layer itself (the Apex REST endpoint it calls still needs its own Apex test class).

**Deployment**: ordinary `sf project deploy start --source-dir force-app/main/default/uiBundles/<AppName>` (plus the `CustomApplication` it depends on) — the built `dist/` output is deployed, not source; versioned via `<version>`/`<isActive>` in the `.uibundle-meta.xml`. Fully DX/CI-CD compatible, same as any other metadata type.

**App Builder / Lightning integration**: a Multi-Framework app is **not** a drag-and-drop Lightning App Builder component the way an LWC is. It launches as its own full-page app from the App Launcher. Embedding it inside an existing Lightning record page as a microfrontend iframe (via a thin LWC wrapper around the new `lightning-ui-embedding` base component) is possible but is explicitly documented as **Beta**. We call this out as a real, current limitation rather than treating React as a full LWC replacement for record-page composition.

**Sources** (fetched live during Phase 1, 2026-09-21):
- Salesforce Multi-Framework Overview — `developer.salesforce.com/docs/platform/multiframework/guide/reactdev-overview.html`
- Set Up Your Org for Multi-Framework App Development — `.../reactdev-setup.html`
- Project Structure and Metadata — `.../mfw-project-structure.html`
- Generate an App from a Template — (linked from Get Started nav)
- Work with the Data SDK — `.../data-sdk-intro.html`
- Test Your App — `.../mfw-testing.html`
- Deploy and Publish a UIBundle — `.../mfw-deploy.html`
- Embed Your App in Salesforce with Microfrontends (Beta) — (linked from Test/Deploy/Distribute nav)
- Salesforce Developers Blog: "Build with React, Run on Salesforce: Introducing Salesforce Multi-Framework" (April 2026) and "Build with React on Salesforce: Multi-Framework Is Now GA" (July 2026)

## 5. Fairness rules applied to all four builds

1. Same three entities, same fields, same filter/update behavior, same states (loading/empty/error).
2. No implementation gets scaffolding, error handling, or polish the others don't.
3. Apex selector/service logic is shared *conceptually* (same query shape, same bulkification/FLS approach) but each framework gets its own controller/service class per the platform's own idioms — we do not force a single shared Apex class where the calling convention differs (VF/Aura/LWC share reusable selector classes directly; React's Apex REST class reuses the selector classes too, but exposes them differently because it must).
4. No performance numbers are claimed anywhere unless we run an actual controlled measurement in Phase 8/9.

## 6. Next: Phase 2

Build the shared data model (custom fields if any are needed — likely none, standard Account/Contact/Opportunity suffice) and the shared Apex selector/service layer that Visualforce, Aura, and LWC will all call, plus the Apex REST endpoint for React.
