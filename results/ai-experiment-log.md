# AI Coding Experiment Log

This log records what actually happened while an AI coding agent (Claude, via Claude Code) built all four implementations against a real Salesforce org (`orgfarm-c0edc8e06c-dev-ed`), including every mistake, hallucination risk avoided, and correction required. Nothing here is edited after the fact to look cleaner than it was. Every entry uses the same structure so severity and detectability can be compared directly:

- **Expected**: what the agent assumed would happen
- **Generated/implemented**: what the agent actually wrote
- **Observed**: what actually happened when it was deployed/run/tested
- **Root cause**: the real, verified reason
- **Fix**: what changed
- **Could automated testing catch it?** — and if not, what did

Methodology: each framework was built, then deployed to the real org and either unit-tested (Apex/Jest/Vitest) or smoke-tested live in a browser (or both) before moving to the next phase. Every failure below is a real compiler/test/deploy/runtime error, not a hypothetical.

---

## Cross-cutting (Apex backend, used by all four)

### 1. Apex class-name length limit

- **Expected**: `VisualforceAccountDashboardControllerTest` was a reasonable, descriptive test class name.
- **Generated/implemented**: exactly that 43-character class name.
- **Observed**: `sf project deploy start` failed: `Identifier name is too long: VisualforceAccountDashboardControllerTest`.
- **Root cause**: Apex enforces a 40-character limit on class identifiers; the agent didn't check length before naming.
- **Fix**: renamed to `VisualforceDashboardControllerTest` (35 chars).
- **Could automated testing catch it?** No test needed to run — this is a compile/deploy-time failure. It was caught immediately and unambiguously by the deploy step itself, before any test executed.

### 2. State/country picklist validation

- **Expected**: `Account(BillingState = 'CA')` would insert cleanly, as it would in a typical org.
- **Generated/implemented**: `TestDataFactory.createAccount()` set `BillingState` alone.
- **Observed**: Every Account insert in every test failed: `FIELD_INTEGRITY_EXCEPTION, A country/territory must be specified before specifying a state value`.
- **Root cause**: this specific org has state/country picklists enabled, which requires a valid state+country pair, not a free-text state. This is an org configuration fact, not something inferable from the code.
- **Fix**: removed `BillingState`/`BillingCountry` from test data entirely — the field is display-only in this app and never validated by app logic, so the test doesn't need a real value.
- **Could automated testing catch it?** Yes, and did — every Apex test using `TestDataFactory` failed immediately with a clear, specific error message. Caught on the first deploy attempt.

### 3. Contact duplicate-detection rule

- **Expected**: `contact0@example.com`, `contact1@example.com`, etc., generated fresh per test method, would never collide.
- **Generated/implemented**: an index-based email pattern reset to 0 for every `createContacts()` call, so two different Accounts in the same test method (or across test methods sharing a transaction) produced identical emails.
- **Observed**: `System.DmlException: Insert failed... DUPLICATES_DETECTED` on the second batch of Contacts in a test.
- **Root cause**: Salesforce's standard Contact duplicate rule matches on Email/Name; the test factory's per-call-scoped counter didn't guarantee global uniqueness within a test run.
- **Fix**: added a class-level monotonically increasing counter shared across all `TestDataFactory` calls, guaranteeing unique emails/names for the whole test run.
- **Could automated testing catch it?** Yes — caught by the Apex test run itself, with a specific, actionable error code (`DUPLICATES_DETECTED`).

### 4. `StageName` not a restricted picklist (invalid values accepted silently)

- **Expected**: updating `Opportunity.StageName` to `"Not A Real Stage"` would throw `DmlException` (invalid picklist value), so a test asserting that exception would pass.
- **Generated/implemented**: `OpportunitySelector.updateStage()` did a plain `Database.update()` with no value validation, assuming the platform would reject an invalid Stage.
- **Observed**: the test `updateStageWithInvalidPicklistValueThrows` failed — no exception was thrown; the invalid string was saved as-is.
- **Root cause**: `StageName` is not configured as a *restricted* picklist in this org, so Salesforce accepts any string value for it. This is an assumption about platform behavior that turned out to be org-configuration-dependent, not universally true.
- **Fix**: added explicit validation in `OpportunitySelector.updateStage()` against the field's active picklist values before the DML, raising a dedicated `InvalidStageException`. This is a generalizable defensive-coding lesson: never assume a standard picklist field rejects out-of-list values without checking `isRestricted()` or validating explicitly.
- **Could automated testing catch it?** Yes — an Apex test wrote the exact scenario and failed clearly, with no ambiguity about what went wrong.

### 5. `AuraHandledException` message not visible to client (proactively avoided, not a mistake)

- **Expected/known risk**: `AuraHandledException`'s constructor argument is not automatically surfaced via `getMessage()` on the client without also calling `setMessage()` — a well-known Apex/LWC gotcha the agent was aware of from training.
- **Generated/implemented**: a centralized `wrapError()` helper in `AccountDashboardController` that calls both the constructor and `setMessage()` on every throw path.
- **Observed**: correct client-visible error messages, confirmed by a dedicated test (`getDashboardWithInvalidAccountThrowsAuraHandledExceptionWithMessage`) asserting the message isn't the generic placeholder.
- **Root cause**: n/a — this row documents a mistake *avoided*, not made.
- **Fix**: n/a.
- **Could automated testing catch it?** The test written specifically targets this gotcha and would have caught it had the mistake been made.

### 6. Apex code-coverage gate on deploy

- **Expected**: a Developer Edition org would not enforce the 75%-per-class coverage gate the way production orgs do.
- **Generated/implemented**: several getters (`getStageOptions`, `getOpportunityOptionsForUpdate`, `doSearch`, `applyStageFilter`) and defensive `catch (Exception e)` branches were left untested initially.
- **Observed**: `sf project deploy start` failed on two classes sitting at 73.9%/62.2% coverage.
- **Root cause**: this org *does* enforce the standard coverage gate (Developer Edition is not exempt the way scratch/sandbox orgs are).
- **Fix**: added real tests for the untested getters, plus a genuine FLS/permission-failure test using the `Minimum Access - Salesforce` profile and `System.runAs` — which also directly satisfies the required "permission/security failure" acceptance scenario, so it wasn't coverage padding.
- **Could automated testing catch it?** The deploy step itself caught it immediately, with an exact percentage and class name.

---

## Visualforce

### 7. Bare public fields don't bind in Visualforce's expression language

- **Expected**: a wrapper class's `public String name;` field would resolve via `{!accountSummary.name}` in Visualforce EL, the same way it resolves for `sf.getAccountSummary()` at the top level.
- **Generated/implemented**: `AccountDashboardDTO`'s inner classes used bare public fields (`public String name;`), not properties.
- **Observed**: deploying `AccountDashboard.page` failed with `Unknown property 'AccountDashboardDTO.AccountSummary.name'`.
- **Root cause**: Visualforce's EL requires a real Apex property (`{ get; set; }`) to resolve a member one level deep on a custom Apex type; a bare public field is not enough, even though `@AuraEnabled`/JSON serialization work fine with either form. This is a genuinely non-obvious, generalizable Visualforce fact, not specific to this project.
- **Fix**: converted every DTO field to a real property.
- **Could automated testing catch it?** No Apex unit test would catch this — it's purely a Visualforce-page compile/deploy-time binding check. The deploy step caught it immediately and specifically named the exact broken property path.

### 8. `apex:pageBlockTable` outside `apex:pageBlock`

- **Expected**: `apex:pageBlockTable` could be used freely inside any container, styled with SLDS classes instead of the classic pageBlock chrome.
- **Generated/implemented**: `apex:pageBlockTable` inside plain `<div>`s.
- **Observed**: deploy failed: `<apex:pageBlockTable> must be contained in <apex:pageBlock> or <apex:pageBlockSection>`.
- **Root cause**: this is a hard structural requirement of the component, not a style preference — an outdated assumption that it was purely presentational.
- **Fix**: replaced with `apex:repeat` + hand-built SLDS `<table>` markup, arguably a *more* current pattern for an SLDS-only Visualforce page than the classic pageBlock chrome would have been.
- **Could automated testing catch it?** No — deploy-time markup validation caught it, not a test.

---

## Aura

No deploy or runtime errors occurred on the first attempt. Verified live in the org (search → select → dashboard load → stage filter → update-stage controls all rendered and worked) via a thin standalone `.app` launcher. This is itself a finding, not an absence of one: see `docs/findings.md`, Finding 2.

---

## LWC

### 9. `lightning-combobox` bound to the wrong data shape — passed all unit tests

- **Expected**: passing the raw Apex search results (`{id, name}` objects) directly as a `lightning-combobox`'s `options` would render the dropdown correctly, the same casual pattern used successfully elsewhere.
- **Generated/implemented**: `<lightning-combobox options={accountOptions}>` bound directly to the raw DTO array.
- **Observed**: **all 6 Jest tests passed.** Live in the browser, the Account dropdown opened empty — no options rendered at all.
- **Root cause**: `lightning-combobox` requires an `options` array shaped `{label, value}`; a `{id, name}` shape is silently accepted by the component's API surface (no runtime error) but produces no renderable options.
- **Fix**: added an `accountComboboxOptions` getter mapping `{id, name} → {value, label}`, and bound the template to that instead.
- **Could automated testing catch it? — explicitly, why not**: **No, and this is the single most important finding in this log.** The Jest tests dispatched synthetic `CustomEvent('change', { detail: { value: '001...' } })` events directly at the `lightning-combobox` element to test the *change handler*. This never asked the combobox to render its `options` prop into real DOM — the exact code path where the bug lived. A test that reads the actual rendered `<option>`-equivalent nodes, or a live browser click on the dropdown, would have caught it; a synthetic change event cannot, by construction, since it bypasses rendering entirely. **Only live, real-org browser verification caught this.** It's documented in detail in `docs/findings.md` under "Why the LWC tests didn't catch it."

### 10. Jest test used the wrong `querySelectorAll` index

- **Expected**: the first `lightning-combobox` in the rendered DOM would be the Stage filter.
- **Generated/implemented**: a test indexed `querySelectorAll('lightning-combobox')[0]` assuming that.
- **Observed**: test failure — index 0 was actually the persistent "Select an Account" combobox, which stays rendered after the dashboard loads.
- **Root cause**: a test-authoring mistake (miscounted DOM order), not an application bug.
- **Fix**: corrected the indices with an explanatory comment.
- **Could automated testing catch it?** Yes — this was itself caught by running the test suite, which is precisely how test bugs get caught.

---

## React (Salesforce Multi-Framework)

This phase carried the most genuine platform-newness risk (Multi-Framework reached GA in July 2026) and, on first pass, the most unresolved issues. A dedicated follow-up investigation (documented fully in `docs/findings.md`) resolved both open items below with a precise root cause and fix for one, and a rigorously isolated (though not platform-confirmed) reproduction for the other.

### 11. `npm install` crashed with an Arborist internal error

- **Expected**: the officially generated `reactbasic`/`reactinternalapp` template's `package.json` would install cleanly with `npm install`.
- **Generated/implemented**: n/a — this is a tooling failure, not application code.
- **Observed**: `npm error Cannot read properties of null (reading 'edgesOut')` — a known class of npm 10.x peer-dependency resolution bug.
- **Root cause**: npm's Arborist dependency resolver, not this project's code.
- **Fix**: retried with `npm install --legacy-peer-deps`, which succeeded.
- **Could automated testing catch it?** N/A — this occurs before any test or app code runs.

### 12. `--legacy-peer-deps` silently installed an incompatible transitive dependency

- **Expected**: the workaround above would have no other side effects.
- **Generated/implemented**: n/a.
- **Observed**: the production build failed: `Missing "./sf_mcpanalytics" specifier in "o11y_schema" package`.
- **Root cause**: `@salesforce/platform-sdk` declares `o11y_schema: ">=264.85.0"`, but the legacy resolver installed `o11y_schema@252.11.0` anyway — confirmed via `npm ls o11y_schema`, which explicitly showed `invalid: ">=264.85.0"`.
- **Fix**: explicitly installed the correct `o11y_schema`/`o11y` versions; production build then succeeded.
- **Could automated testing catch it?** No unit test would catch this — it's a build-time failure, caught by running `npm run build`, which is exactly the step that caught it.

### 13. `@testing-library/react` missing its `@testing-library/dom` peer

- **Expected**: the official template's `package.json` listed all necessary test dependencies.
- **Generated/implemented**: n/a — a gap in the officially generated scaffold, not this project's code.
- **Observed**: Vitest failed: `Cannot find module '@testing-library/dom'`.
- **Fix**: installed it directly.
- **Could automated testing catch it?** Yes — the test runner itself failed to even start, immediately and unambiguously.

### 14. App Launcher visibility — root cause found and fixed (previously reported as an open/unresolved gap)

- **Expected**: a hand-authored `CustomApplication` referencing a deployed `UIBundle`, plus a `PermissionSet` granting `applicationVisibilities`, would be sufficient for the app to appear in the Lightning App Launcher, matching a literal reading of the "Manage Your App and Grant User Access" documentation's troubleshooting checklist (target=CustomApplication, uiBundle reference correct, UIBundle isActive, permission set granted).
- **Generated/implemented**: a minimal `CustomApplication` with only `<label>` and `<uiBundle>`, and a `PermissionSet` with only `applicationVisibilities`.
- **Observed**: the app deployed successfully and appeared in Setup's App Manager, but did not appear in the App Launcher.
- **Root cause, found by regenerating and diffing against the official `reactinternalapp` template** (not assumed): the official template's `CustomApplication` also sets `uiType` (`Lightning`), `navType` (`Standard`), `formFactors`, and a `brand` block, none of which this project's hand-authored version had. Separately, the official template's generated `<AppName> Access` permission set grants **both** `applicationVisibilities` **and** the `ApiEnabled` user permission — this project's only granted the former. Attempting to patch the existing `CustomApplication` with the missing `uiType` failed deploy outright with `UiType isn't updateable for custom apps.` — `uiType` is set-once-at-creation-only.
- **Fix**: created a new `CustomApplication` (`AccountDashboardReactApp`) with the full, correct field set matching the official template exactly, and added `ApiEnabled` to the permission set. Redeployed successfully. The app then appeared in both Setup's App Manager and the Lightning App Launcher, and opening it correctly launched the real `*.my.salesforce.app` deployment.
- **Could automated testing catch it?** No — there is no automated test for "does this app appear in the App Launcher UI." This required (a) comparing generated reference metadata field-by-field against hand-authored metadata, and (b) live browser verification after the fix. Neither Apex tests, Jest, nor Vitest exercise this surface at all.

### 15. Local dev-proxy 401 on Apex REST — investigated scientifically, not assumed to be a platform bug

- **Expected**: `sf ui-bundle dev` (Salesforce's own local live-preview tool) would authenticate calls to a custom Apex REST endpoint the same way it authenticates UI API calls, since the Data SDK's own bundled configuration explicitly lists `services/apexrest` as a protected/authenticated URL.
- **Generated/implemented**: `src/api/accountDashboard.ts` calling `dataSdk.fetch('/services/apexrest/AccountDashboard/...')`, exactly as documented.
- **Observed**: `GET /services/data/v67.0/ui-api/records/{id}` through the local proxy returned a real, authenticated Salesforce response (404/403 depending on the id); `GET /services/apexrest/AccountDashboard/stages` through the same proxy, same session, returned `401 {"errorCode":"INVALID_SESSION_ID"}`.
- **Isolation performed before drawing any conclusion**: deployed a brand-new, single-method, zero-logic Apex REST class (`MinimalRestPing`) to the same org from a completely fresh, unmodified `reactinternalapp` scaffold, and called it through the same local proxy. It returned the **identical** `401 INVALID_SESSION_ID` — ruling out anything specific to this project's own Apex REST class or its complexity.
- **Root cause**: not confirmed as an official Salesforce defect — no Salesforce issue tracker entry or documentation page was found describing this behavior, and per the explicit instruction for this investigation, it is therefore **not** classified as a confirmed platform bug.
- **Fix / practical conclusion**: **reported as a reproducible behavior observed with this specific environment/toolchain snapshot** (CLI 2.150.6, Node v23.6.1/v24.19.0 bundled, npm 10.9.2, `@salesforce/platform-sdk` 11.71.5, `@salesforce/plugin-ui-bundle-dev` 1.2.4, API v67.0, Developer Edition/Hyperforce org), isolated to `/services/apexrest/*` specifically and not `/services/data/*`. Critically, **this limitation does not affect the deployed production app** — the identical Apex REST endpoint, called from the real `*.my.salesforce.app` deployment (not the local proxy), returned real data successfully in the full end-to-end test documented in `docs/findings.md`. Practical guidance recorded for other developers: validate Apex REST integrations against a deployed org, not solely `sf ui-bundle dev`, with this toolchain version.
- **Could automated testing catch it?** No — Vitest (mocking the API module) and the Apex REST class's own unit tests (running server-side, with no local proxy involved) both passed and both remain valid; neither exercises the local dev-proxy's authentication path at all. Only manually inspecting real network requests in a live browser session against the running local dev server surfaced this.

---

## Honest summary

- **Hallucinated Salesforce APIs**: none identified. Every Apex, LWC, Aura, and Multi-Framework API used was either directly verified against installed package type definitions (`@salesforce/platform-sdk`), verified against currently-fetched Salesforce documentation, verified by regenerating and diffing an official CLI template, or is long-standing stable Apex/LWC surface.
- **Outdated patterns caught before deploy or by deploy failure**: the `apex:pageBlockTable` nesting rule and the Visualforce bare-field binding rule.
- **Governor-limit/security concerns surfaced and fixed**: FLS/CRUD via `WITH USER_MODE` + `AccessLevel.USER_MODE` throughout, explicit picklist validation, row caps at 200, a real permission-failure test using a genuinely restricted profile (not a mock).
- **Issues resolved only by regenerating official reference metadata and diffing**, not by assumption: the entire App Launcher visibility root cause (finding #14).
- **Issues resolved only by isolated, minimal, scientific reproduction**, not by assumption: the local dev-proxy 401 (finding #15) — investigated with a purpose-built minimal Apex REST class in a fresh reference project specifically to rule out causes specific to this project's own code.
- **The single most important process lesson**: the LWC combobox options-shape bug (finding #9) passed 100% of unit tests and was only caught by live, real-org browser verification — a concrete, evidenced case for why "tests pass" and "the feature works" are not the same claim, especially for UI components with client-side data binding.
