# Comparison — Visualforce vs. Aura vs. LWC vs. React (Multi-Framework)

Raw counts backing every claim here are in [results/comparison.md](../results/comparison.md). This document is the narrative read of those numbers, plus the qualitative developer-experience differences that don't show up in a line count.

## 1. Data-access complexity

All four read the same three objects and write one field. The *shape* of getting there differs sharply:

- **Visualforce & Aura & LWC**: one shared `@AuraEnabled`/plain-Apex call pattern, either directly (Aura/LWC via `AccountDashboardController`) or through a custom controller (VF via `VisualforceAccountDashboardController`) — both ultimately calling the same `AccountDashboardService`. A developer who knows Apex can trace the entire data path in one file.
- **React**: cannot reach that same Apex surface at all. It needs its own Apex REST resource (`AccountDashboardRestResource`, 64 lines that don't exist for the other three) and a client-side fetch wrapper (`src/api/accountDashboard.ts`) that manually constructs REST URLs, checks `response.ok`, and parses a JSON error envelope by hand — none of which LWC's `@wire`/imperative Apex or Aura's `$A.enqueueAction` require, since those runtimes handle transport, serialization, and error-shape normalization for you.

**Verdict**: React's data-access layer is objectively more code, and more of it is hand-rolled plumbing (URL building, response parsing) rather than business logic, compared to the other three.

## 2. State-management complexity

- **Visualforce**: state lives entirely on the server-side controller between requests. There is no client-side state model to reason about, but every state change (search, filter, edit) is a round trip; the "state machine" is really just "what does the next page render look like."
- **Aura**: explicit, hand-maintained boolean attributes (`hasError`, `hasDashboard`, `hasContacts`, `hasOpportunities`, `searchAttempted`) alongside the data attributes, because Aura's expression language can't reliably do compound truthy/length checks inline. This is real, avoidable-feeling boilerplate that LWC and React don't need.
- **LWC**: plain class fields plus getters (`hasError`, `filteredOpportunities`, `pipelineTotal` computed on read) — no manual boolean bookkeeping, because JS getters can express `!!this.errorMessage` or `.length > 0` directly in the template.
- **React**: `useState` + `useMemo`, functionally identical to LWC's getter pattern, arguably very slightly more concise because `useMemo` handles the derived-value memoization LWC getters recompute on every access (a real, minor performance difference, not benchmarked here).

**Verdict**: LWC and React have the least state-management boilerplate; Aura has the most, entirely because of its expression-language limitations, not because the underlying problem is harder.

## 3. Testing complexity

- **Visualforce & Aura**: no dedicated client-side test runner is idiomatic for either (Aura's own `aura:test` framework is legacy and effectively unused in modern Aura development). Confidence comes entirely from Apex tests plus manual/browser verification — which is exactly what this project did.
- **LWC**: `@salesforce/sfdx-lwc-jest`, already wired into a standard SFDX project's `package.json`. Fast, offline, no org connection needed.
- **React**: Vitest + Testing Library, also fast and offline — but it is *not* Salesforce tooling; it's the same stack any React project would use. This is a genuine advantage for a team that already has React test conventions, and a genuine disadvantage for a team that only knows Salesforce-flavored testing.
- **A real, load-bearing finding from this project**: the LWC Jest suite passed 6/6 while a real bug shipped (the Account combobox rendered empty, described in `results/ai-experiment-log.md`), because the tests dispatched synthetic `change` events instead of exercising the actual `lightning-combobox` rendering path. **Unit tests for data-bound UI components are not a substitute for at least one real, live-org smoke test** — true for all four frameworks, but LWC/Aura's data-binding-heavy templates make this risk especially easy to miss.

## 4. Debugging experience

- **Visualforce**: server-side view-state errors and full-page reloads make debugging slower to iterate but easier to reason about (it's just an HTTP request/response cycle) — no browser dev tools JS debugging needed for most issues.
- **Aura**: browser dev tools plus Salesforce's Lightning-specific console warnings; the controller/helper split adds a layer of indirection when tracing a bug.
- **LWC**: standard browser dev tools work almost unmodified (real DOM, real classes); Salesforce-specific failures (FLS/CRUD, `AuraHandledException` message truncation) are the main non-obvious category, and this project hit one of those (the `AuraHandledException.setMessage()` gotcha) and had to know to look for it.
- **React**: entirely standard browser/React DevTools debugging, plus one new failure mode unique to Multi-Framework: dependency resolution and build-tool errors (see the `o11y_schema` version-skew issue in the AI experiment log) that have nothing to do with Salesforce logic at all and require npm/Vite literacy to diagnose.

## 5. Developer tooling & local-development experience

- **Visualforce & Aura & LWC**: `sf project deploy start` is the entire feedback loop; there is no separate local dev server for VF/Aura, and LWC's local preview options are limited compared to a full dev server.
- **React**: a genuine local dev server (`npm run dev`, Vite, hot module reload) plus `sf ui-bundle dev`, which proxies authenticated requests to the real org so the local dev server can call live Apex REST/GraphQL without deploying. This is a materially better local iteration loop *once it's running* — but getting there took more troubleshooting in this project than any other framework (see the AI experiment log's npm/port/proxy issues), and is the one part of the whole stack that depends on tooling outside Salesforce's control (npm, Node version compatibility, transitive dependency resolution).

## 6. App Builder / Lightning platform integration

- **Visualforce & Aura**: launch as their own page/app; no App Builder drag-and-drop composition (Aura components *can* be added to Lightning pages, VF pages cannot).
- **LWC**: the only one of the four that can be dropped directly onto a Lightning record/app/home page via App Builder with zero extra metadata.
- **React (Multi-Framework)**: launches as its own standalone app from the App Launcher (like Aura/VF), **not** as an App Builder-composable component. Embedding it inside an existing Lightning page as a microfrontend iframe is possible via `lightning-ui-embedding`, but that capability is explicitly **Beta**, and — a concrete, first-hand finding from this project — getting a hand-assembled `CustomApplication`+`UIBundle` to actually surface in the App Launcher's app list took real, unresolved-within-this-session troubleshooting (see `results/ai-experiment-log.md`); the fully-generated `reactinternalapp` project template (which this project did not use, opting for the bundle-only `reactbasic` template against an existing project) likely handles this more smoothly out of the box.

## 7. Portability outside Salesforce

- **Visualforce & Aura**: effectively zero portability; both are Salesforce-proprietary markup and runtime.
- **LWC**: the component *shape* (standard Web Components) is portable in principle, but `lightning/*` imports, `@wire`, and Lightning Data Service are not — a meaningful rewrite is needed to run an LWC outside Salesforce.
- **React**: the highest portability of the four by a wide margin. Strip out `src/api/accountDashboard.ts` (Salesforce-specific data access) and everything else — components, hooks, routing, styling — is ordinary React that runs anywhere. This is the single biggest, least arguable advantage React has over the other three.

## 8. Learning curve

- **Visualforce**: requires learning a full templating language (`apex:*`) plus the request/view-state mental model — a real, separate skill from both Apex and modern web development, with a shrinking pool of people learning it fresh today.
- **Aura**: requires learning `aura:*` markup, the controller/helper/event split, and its more manual state-handling idioms — also fairly separate from modern web development, and Salesforce's own guidance already directs new development to LWC instead.
- **LWC**: requires learning Salesforce-specific decorators/wire adapters and Lightning Data Service, but sits on top of standard Web Components — a JS/TS developer's existing knowledge transfers more than with VF or Aura.
- **React (Multi-Framework)**: for a developer who already knows React, the *net new* material is small and concentrated: the Data SDK's `createDataSDK`/`gql`/`fetch` surface, the UIBundle deployment model, and the constraint list of what's unavailable (`@wire`, `lightning/*`, `@AuraEnabled`). For a developer who does not know React, the learning curve is the same as learning React itself, which Visualforce/Aura/LWC don't require at all.

## Summary table

| Dimension | Visualforce | Aura | LWC | React (Multi-Framework) |
|---|---|---|---|---|
| Data-access complexity | Low (1 shared path) | Low (1 shared path) | Low (1 shared path + LDS) | Higher (separate REST layer required) |
| State-mgmt boilerplate | N/A (server-driven) | High (manual booleans) | Low (getters) | Low (hooks) |
| Client-side test tooling | None (Apex only) | None (Apex only) | Jest, org-independent | Vitest, org-independent |
| App Builder composability | None | Partial | Full | None (Beta iframe embedding only) |
| Portability off-platform | None | None | Low | High |
| Deploy/build friction hit in this project | Low (2 real errors) | None | Low (1 real error) | Highest (4 real errors, mostly tooling) |
| Learning curve for an experienced web dev | Steep, VF-specific | Steep, Aura-specific | Moderate, standards-based | Low if React is already known |
