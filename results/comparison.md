# Exact Comparison Metrics

Every number in this document was computed directly from the repository with `wc -l` and `find`, on the files listed, on the date this document was last generated. No files were cherry-picked or excluded to make a framework look better or worse. Where a category (e.g., React's scaffold) is large, the full count is shown rather than a curated subset. No performance numbers appear anywhere — none were measured under controlled conditions.

## Methodology

- **LOC** = raw line count (`wc -l`), including comments and blank lines, of the file(s) named. This is a volume metric, not a complexity metric — it is reported because it's objective and reproducible, not because more/fewer lines is inherently better or worse.
- **"Shared backend"** = Apex classes whose logic is identical regardless of which UI calls them (`AccountSelector`, `ContactSelector`, `OpportunitySelector`, `AccountDashboardDTO`, `AccountDashboardService`, `TestDataFactory`, and their test classes). These are counted once, separately, and not duplicated into each framework's own total.
- **"Framework-specific"** = every file that exists *because* a particular UI technology requires its own entry point, markup, or client logic: the VF controller extension + page, the Aura component/controller/helper/launcher, the LWC bundle, the React REST resource + client + component, and each one's own tests.
- **Metadata/config files** (`*-meta.xml`, `ui-bundle.json`, build/test config) are counted separately from markup/logic LOC so the comparison isn't distorted by boilerplate config.
- React's own project scaffold (shadcn/ui components, Vite/TS/ESLint/Playwright config) that Salesforce's official template generates and this project did not author or modify is reported as its own, clearly labeled total — not folded into "authored" LOC, and not hidden.

## Shared backend (used by all four UIs, directly or via a thin per-UI entry point)

| File | LOC | Type |
|---|---:|---|
| `AccountSelector.cls` | 31 | Apex (prod) |
| `ContactSelector.cls` | 18 | Apex (prod) |
| `OpportunitySelector.cls` | 41 | Apex (prod) |
| `AccountDashboardDTO.cls` | 74 | Apex (prod) |
| `AccountDashboardService.cls` | 101 | Apex (prod) |
| `TestDataFactory.cls` | 84 | Apex (test helper) |
| `AccountSelectorTest.cls` | 50 | Apex (test) |
| `ContactSelectorTest.cls` | 39 | Apex (test) |
| `OpportunitySelectorTest.cls` | 58 | Apex (test) |
| `AccountDashboardServiceTest.cls` | 95 | Apex (test) |
| **Shared backend total** | **591** | **10 files** |

## Framework-specific backend entry points

| File | LOC | Used by |
|---|---:|---|
| `AccountDashboardController.cls` | 55 | Aura + LWC (shared between these two only) |
| `AccountDashboardControllerTest.cls` | 96 | Aura + LWC |
| `VisualforceAccountDashboardController.cls` | 144 | Visualforce only |
| `VisualforceDashboardControllerTest.cls` | 153 | Visualforce only |
| `AccountDashboardRestResource.cls` | 64 | React only |
| `AccountDashboardRestResourceTest.cls` | 140 | React only |

**Apex grand total (shared + all entry points): 1,243 lines across 16 files** — matches `find force-app/main/default/classes -name "*.cls" | xargs wc -l`.

## Per-framework UI layer (markup + client logic + metadata, own files only)

### Visualforce — 2 files

| File | LOC |
|---|---:|
| `AccountDashboard.page` | 140 |
| `AccountDashboard.page-meta.xml` | 7 |
| **Total** | **147** |

Apex used: the framework-specific `VisualforceAccountDashboardController` (297 incl. test) + shared backend (591). **No client-side JavaScript.**

### Aura — 6 files

| File | LOC |
|---|---:|
| `accountDashboard.cmp` | 165 |
| `accountDashboard.cmp-meta.xml` | 5 |
| `accountDashboardController.js` | 32 |
| `accountDashboardHelper.js` | 129 |
| `accountDashboardApp.app` (launcher, part of the real deliverable — Aura has no other way to open a component standalone) | 3 |
| `accountDashboardApp.app-meta.xml` | 5 |
| **Total** | **339** |

Apex used: the Aura+LWC-shared `AccountDashboardController` (151 incl. test) + shared backend (591). No dedicated Aura test framework was used (Aura's own `aura:test` tooling is legacy); confidence comes from the shared Apex tests plus live browser verification.

### LWC — 3 files (+1 test file)

| File | LOC |
|---|---:|
| `accountDashboardLwc.html` | 150 |
| `accountDashboardLwc.js` | 202 |
| `accountDashboardLwc.js-meta.xml` | 13 |
| **Prod total** | **365** |
| `__tests__/accountDashboardLwc.test.js` | 171 |

Apex used: the Aura+LWC-shared `AccountDashboardController` (151 incl. test) + shared backend (591). Also uses `lightning/uiRecordApi.updateRecord` (Lightning Data Service) for the Stage update — a second, non-Apex backend call path unique to LWC among the four.

*A thin, dev-only Aura harness (`accountDashboardLwcHost.app`, 16 lines) was used to preview the LWC in a browser, since LWC has no standalone-URL launcher the way Aura does. It is not part of the LWC deliverable and is excluded from the LWC total above.*

### React (Salesforce Multi-Framework) — 4 authored files, inside a 49-file generated project

| File | LOC |
|---|---:|
| `src/api/accountDashboard.ts` | 109 |
| `src/components/AccountDashboard.tsx` | 297 |
| `src/components/AccountDashboard.test.tsx` | 112 |
| `src/pages/Home.tsx` | 5 |
| **Authored total** | **523** |

| Full generated project (for transparency, not attributed as "authored") | Count |
|---|---:|
| Total files under `src/` (authored + scaffold-generated shadcn/ui kit, routing, hooks) | 49 |
| Total LOC under `src/` | 6,159 |
| Root config files (package.json, tsconfig, vite/vitest/playwright/eslint configs, etc., excluding the 23,637-line generated `package-lock.json`) | 22 files / 714 LOC |

Apex used: the React-only `AccountDashboardRestResource` (204 incl. test) + shared backend (591). Also required: `UIBundle`, `CustomApplication`, and `PermissionSet` metadata (33 lines combined) that no other framework needs.

## Backend calls per framework (distinct server round-trip operations)

| Framework | Calls | Detail |
|---|---:|---|
| Visualforce | 3 | `AccountDashboardService.searchAccounts` / `.getDashboard` / `.updateOpportunityStage` — direct in-process Apex calls from the controller extension (no serialization boundary) |
| Aura | 4 | `AccountDashboardController.searchAccounts` / `.getDashboard` / `.getOpportunityStages` / `.updateOpportunityStage` via `$A.enqueueAction` |
| LWC | 4 | `AccountDashboardController.searchAccounts` / `.getDashboard` / `.getOpportunityStages` (imperative Apex, 3 calls) **+** `lightning/uiRecordApi.updateRecord` (Lightning Data Service, 1 call) for the Stage update — the only framework using two distinct backend APIs |
| React | 4 | `dataSdk.fetch()` against `/services/apexrest/AccountDashboard/search`, `/{id}`, `/stages`, and a `PATCH` to `/{id}` — all REST, no GraphQL used in this implementation |

## Framework-specific APIs/concepts exercised (count of distinct concepts, listed)

| Framework | Count | Concepts |
|---|---:|---|
| Visualforce | 10 | `apex:page`, `apex:form`, controller extension pattern, `apex:actionStatus`, `apex:commandButton`, `apex:actionSupport`, `apex:outputPanel`, `apex:repeat`, `apex:pageMessages`, `SelectOption` |
| Aura | 9 | `aura:component`, `aura:attribute`, `aura:handler` (init), `aura:if`, `aura:iteration`, `$A.enqueueAction`, `component.get/set`, Lightning base components (`lightning:input/select/button/spinner`), standalone `.app` launcher |
| LWC | 6 | Standard class fields/getters (not Salesforce-specific), `lightning/uiRecordApi.updateRecord`, Lightning base components (`lightning-input/combobox/button/spinner`), `if:true`/`for:each` template directives, `js-meta.xml` target configuration, Jest (`@salesforce/sfdx-lwc-jest`) |
| React | 4 | `@salesforce/platform-sdk` (`createDataSDK`), `dataSdk.fetch()`, `UIBundle`/`CustomApplication`/`PermissionSet` metadata, Apex REST (`@RestResource`) as the integration boundary — everything else (hooks, JSX, routing, Tailwind, Vitest) is standard, non-Salesforce-specific web technology |

This ordering (VF highest, React lowest) reflects how much of each UI's *own* code is Salesforce-proprietary syntax vs. standard web technology — it does not measure total engineering effort, which the LOC tables above address separately.

## Automated tests

| Framework | Tool | Test count | Notes |
|---|---|---:|---|
| Visualforce | Apex (`sf apex run test`) | 10 methods (`VisualforceDashboardControllerTest`) | Runs against the real org |
| Aura | Apex (shared with LWC) | 7 methods (`AccountDashboardControllerTest`) | No dedicated Aura test framework used; runs against the real org |
| LWC | Jest (`@salesforce/sfdx-lwc-jest`) | 6 tests | Local (jsdom), no org connection; 84% statement coverage |
| React | Vitest + Testing Library | 5 tests | Local (jsdom), no org connection |
| Apex (all classes) | `sf apex run test` | 41 test methods across 16 classes, 0 failures | Run repeatedly against the real org during development |

## Deployment metadata required

| Framework | Metadata types | Build step |
|---|---|---|
| Visualforce | `ApexPage`, `ApexClass` | None |
| Aura | `AuraDefinitionBundle` (×2: component + launcher app), `ApexClass` | None |
| LWC | `LightningComponentBundle`, `ApexClass` | None (source deployed directly) |
| React | `UIBundle`, `CustomApplication`, `PermissionSet`, `ApexClass` | **Yes** — `npm run build` (Vite) must run first; the built `dist/` output is what's deployed |

## Real deploy/build/runtime errors hit during development (see `results/ai-experiment-log.md` for full detail)

| Framework | Count | Resolved? |
|---|---:|---|
| Apex (shared, affects all four) | 4 (class-name limit, state/country validation, duplicate-rule collision, StageName validation gap) | All 4 fixed |
| Visualforce | 2 (EL field-binding rule, `pageBlockTable` nesting rule) | Both fixed |
| Aura | 0 | N/A |
| LWC | 1 (combobox options shape — passed unit tests, caught only live) | Fixed |
| React | 5 (npm resolver crash, transitive dependency version skew, missing template peer dependency, App Launcher metadata gap, local dev-proxy 401) | 4 fixed with a confirmed root cause; 1 (local dev-proxy 401) isolated to a specific reproducible toolchain behavior, does not affect the deployed production app, not classified as a confirmed platform defect |
