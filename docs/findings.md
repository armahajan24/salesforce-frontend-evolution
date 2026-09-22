# Findings — Visualforce → Aura → LWC → React: What Should Salesforce Developers Actually Learn Now?

This is the factual findings report for the experiment described in [architecture.md](architecture.md) and backed by the raw data in [../results/comparison.md](../results/comparison.md) and [../results/ai-experiment-log.md](../results/ai-experiment-log.md). It does not assume its conclusion in advance — Visualforce and Aura are evaluated for what they still are today, not dismissed as "dead," and React is evaluated for what it can concretely do today, not for where the roadmap might go.

## What was actually built and verified

The same Account 360 mini-dashboard (search Account → view details/Contacts/Opportunities → filter by Stage → see pipeline total → update a Stage → reload/verify persistence → loading/empty/error states → FLS/CRUD/sharing enforced) was implemented four times against one real Salesforce org (`orgfarm-c0edc8e06c-dev-ed`), sharing one Apex selector/service layer wherever the calling convention allowed it. **All four were verified working end-to-end live in the org** — this was completed for React in a follow-up verification pass after an initial pass left it unresolved; see "Finding 4" below for exactly what that took.

## Finding 1: The shared-backend assumption holds for three of four, and breaks in a measurable way for the fourth

Visualforce, Aura, and LWC all reached the same data through the same Apex service layer (`AccountDashboardService`), differing only in their thin entry points (a controller extension for VF, one `@AuraEnabled` class shared by Aura and LWC). React could not use that specific entry point — see "Apex access, precisely" below for exactly what that does and doesn't mean — and required its own 64-line Apex REST class plus a hand-written fetch client. This is a real, current, documented platform boundary (confirmed against live Salesforce docs, not assumed), and it is the most concrete, measurable finding in the entire project: **React is not a drop-in fourth way to build the same Lightning component — it is a genuinely separate application model that happens to run on the same platform and same data.**

### Apex access, precisely

"React can't call Apex" is too broad and was corrected in this report. What's actually true, distinguishing invocation styles:

| Capability | Aura / LWC | React (Multi-Framework) |
|---|---|---|
| `@salesforce/apex/Namespace.Class.method` imperative/wired call | ✅ Available | ❌ Not available — this import path doesn't resolve outside the LWC/Aura module runtime |
| `@wire` decorator (reactive provisioning from Apex, UI API, etc.) | ✅ Available | ❌ Not available — `@wire` is an LWC-compiler feature; there is no equivalent in a plain React component |
| Lightning base components (`lightning-input`, `lightning-datatable`, etc.) / `lightning/*` modules (`lightning/uiRecordApi`, `lightning/navigation`, etc.) | ✅ Available | ❌ Not available — these ship as part of the Lightning Component Framework runtime, which a Multi-Framework app doesn't run inside |
| **Custom Apex logic, generally** | Via `@AuraEnabled` methods | ✅ **Available** — via an `@RestResource` **Apex REST** endpoint, called from the client with the Data SDK's `dataSdk.fetch()` (confirmed against the SDK's own bundled config, which explicitly lists `services/apexrest` as a supported/protected URL — see `results/ai-experiment-log.md`) |
| UI API record data (Account/Contact/Opportunity CRUD, layouts, etc.) | Via `lightning/uiRecordApi`, `lightning/uiGraphQLApi`, or Apex | ✅ Available directly — via `dataSdk.graphql` (GraphQL over the `uiapi` schema) or `dataSdk.fetch()` against `/services/data/v{version}/ui-api/*` REST endpoints |
| GraphQL | Via `lightning/uiGraphQLApi` (LWC only; not used in this project's LWC build) | ✅ Available — `dataSdk.graphql.query()` / `.mutate()`, the documented preferred path for record data |

**The precise, defensible claim**: a Multi-Framework React app cannot use the *LWC-style Apex invocation surface* (`@salesforce/apex/Class.method`, `@wire`, Lightning base components, `lightning/*`). It *can*, and in this project *does*, run custom Apex logic — through Apex REST, a fully-supported, equally-real integration path, called via the current Data SDK rather than the LWC compiler's wire/import machinery. The two are different plumbing to the same Apex platform, not "React has Apex access" vs. "React has no Apex access."

## Finding 2: Aura's problems are exactly the ones Salesforce says they are, and no more

Aura required the most manual, explicit state bookkeeping of the four (hand-maintained boolean attributes because Aura's expression language can't do compound conditionals inline). It also produced **zero deploy or build errors** in this project — the simplest, most predictable path of the four once you accept its verbosity. This matches Salesforce's own stated position: Aura is stable and fully supported, not broken, just superseded in ergonomics by LWC for new work.

## Finding 3: LWC earned its "current default" status on merit, not by default

LWC had the least state-management boilerplate of the three Lightning-runtime frameworks (getters instead of Aura's manual booleans), the best offline/local test story of the non-React options (Jest, already wired into a standard SFDX project), and is the only one of the four that can be dropped directly onto a Lightning App Builder page with zero extra metadata. It is also the only framework in this project where a real bug shipped past a fully-passing unit test suite and was only caught by live browser verification (a `lightning-combobox` bound to the wrong data shape) — a concrete reminder that LWC's Jest tests, run with synthetic events, do not by themselves prove the real rendering path works. See "Why the LWC tests didn't catch it" below.

### Why the LWC tests didn't catch it

The Jest test suite dispatched synthetic `CustomEvent('change', { detail: { value: '...' } })` events directly at the `lightning-combobox` element — a valid way to test the component's *event handler logic*, but one that never asks the combobox to actually render its `options` array into real DOM options. The bug (raw `{id, name}` objects passed where `{label, value}` was required) lived entirely in that rendering path, which the tests never exercised. All 6 tests passed; the dropdown was empty in a real browser. The general lesson, not unique to this bug: **a synthetic-event unit test proves your change handler works given a value; it does not prove the UI produced that value in the first place.** Only live, real-DOM interaction (or a testing-library query that reads the actual rendered `<option>` elements) would have caught this.

## Finding 4: React (Multi-Framework) is real, current, GA, and — once its metadata is correct — fully functional end-to-end

Every specific capability claim in this project's React implementation was verified against live Salesforce documentation and the actually-installed `@salesforce/platform-sdk` package (v11.71.5), not assumed from training data: GA since July 2026, Hyperforce-only, deployed as a `UIBundle` via ordinary `sf project deploy start`, data access via `dataSdk.graphql`/`dataSdk.fetch`, standard Vitest/Playwright testing. None of that was hallucinated, and none of it required a workaround to use correctly.

**The App Launcher issue was a real, self-inflicted metadata gap, not a platform defect — and it's now fixed and verified.** Regenerating a minimal, current, official `reactinternalapp` project template and diffing its metadata against this project's hand-authored files found the exact, precise cause:

- Our `CustomApplication` was missing `uiType` (`Lightning`), `navType` (`Standard`), `formFactors`, and a `brand` block that the official template always generates.
- `uiType` turned out to be **immutable after a `CustomApplication`'s first creation** — attempting to add it via `sf project deploy start` on the existing component failed outright with `UiType isn't updateable for custom apps.` The fix required creating a new `CustomApplication` (`AccountDashboardReactApp`) rather than patching the old one in place — itself a useful, generalizable fact about this metadata type.
- Our `PermissionSet` granted `applicationVisibilities` (app visibility) but not the `ApiEnabled` user permission, which the official template's generated `<AppName> Access` permission set always includes and which Salesforce's own "Manage Your App and Grant User Access" documentation states is required because the app reads/writes data through the platform API.

After applying both fixes and redeploying, the app was confirmed present in Setup's App Manager and in the Lightning App Launcher (both the quick-search dropdown and the full "All Apps" grid), and selecting it correctly launched it at its real `*.my.salesforce.app` domain URL — exactly as documented. **The full functional flow was then verified live against that deployed production app**: search → select an Account → Account details, Contacts, and Opportunities loaded → pipeline total computed correctly ($175,000, then $50,000 after filtering to Prospecting) → Stage filter narrowed the list correctly → an Opportunity's Stage was updated through the UI → a loading indicator appeared during the update → the dashboard reloaded with the new Stage reflected → **persistence was independently confirmed with a direct SOQL query against the org** (`StageName = 'Qualification'`), not just by trusting the UI's own re-render.

One secondary, minor nuance surfaced during this verification and is recorded rather than hidden: opening the app via the App Launcher's quick-search result launches it correctly; opening the *same* app by clicking its tile in the full "All Apps" grid view instead routed to a generic Lightning app shell ("this app doesn't have any navigation items") rather than the UIBundle content. This appears to be a routing difference between the two App Launcher entry points for a Multi-Framework app specifically, not a defect in this project's metadata (the quick-search path — the one Salesforce's own documentation describes and shows a screenshot of) works correctly and is the supported way to open the app.

### The local dev-proxy 401, investigated scientifically

The empty-search and error-handling states were additionally verified using `sf ui-bundle dev` (Salesforce's own local live-preview tool, proxying authenticated requests from a local Vite dev server to the real org). This surfaced a distinct, separate issue from the App Launcher one above, isolated with a purpose-built minimal reproduction rather than assumed:

**Reproduction**: a brand-new, single-method, zero-logic Apex REST class (`MinimalRestPing`, returning `{"pong":true}`) was deployed to the same org from a completely fresh, unmodified `sf template generate project --template reactinternalapp` scaffold. Calling it through `sf ui-bundle dev`'s local proxy returned the identical result as our own application's Apex REST endpoint:

| Request (via local dev proxy, same session) | Result |
|---|---|
| `GET /services/data/v67.0/ui-api/records/{id}` | `404`/`403` (a real, authenticated Salesforce error response — proves the session **is** valid for UI API paths) |
| `GET /services/apexrest/MinimalRestPing` (brand-new, unrelated endpoint, separate reference project) | `401 {"message":"Session expired or invalid","errorCode":"INVALID_SESSION_ID"}` |
| `GET /services/apexrest/AccountDashboard/stages` (this project's own endpoint) | Identical `401 INVALID_SESSION_ID` |

**Environment recorded for reproducibility**: Salesforce CLI `2.150.6` (win32-x64, bundled Node v24.19.0), system Node `v23.6.1`, npm `10.9.2`, `@salesforce/platform-sdk` `11.71.5`, `@salesforce/plugin-ui-bundle-dev` `1.2.4`, org API version `67.0`, org type Developer Edition on Hyperforce (instance `CAN96`).

**Conclusion, stated at the appropriate confidence level**: this is a **reproducible behavior encountered with this specific environment/toolchain version combination** — the local dev proxy authenticates `/services/data/*` (UI API) calls correctly but returns a generic session-invalid `401` for any `/services/apexrest/*` call, regardless of which Apex REST class is called. No official Salesforce issue tracker entry or documentation page was found confirming this as a known, permanent product defect, so it is **not** classified as one. What is independently and separately confirmed is that **this proxy-only limitation does not affect the deployed production app**: the identical Apex REST endpoint, called from the app's real `*.my.salesforce.app` deployment (not through the local proxy), returned real data successfully in the live end-to-end test described above. The practical implication for a developer: **do not rely on `sf ui-bundle dev` to validate a custom Apex REST integration** in this toolchain version; validate against a deployed org instead, exactly as this project ultimately did.

**Reading this fairly**: none of this means Multi-Framework doesn't work — it works, fully, end-to-end, against a real org, once the metadata is correct. It means that **for a React app on Salesforce, a meaningful share of the operational risk has moved from "did I use the Salesforce API correctly" (largely solved, well-documented, and well-tooled) to "did my npm dependency graph, CLI tooling, and generated metadata resolve completely and correctly" (rougher, evidenced directly and specifically in this project, and in every case resolved once properly diagnosed)** — a genuinely different risk profile than the other three frameworks, none of which needed anything beyond a standard Salesforce CLI deploy.

## Finding 5: The "which one is more Salesforce-specific" intuition is directionally right, and React's portability advantage is real and large

React's application code (outside of one small `src/api/` file) is ordinary, portable React — nothing about `AccountDashboard.tsx` or its test would need to change to run outside Salesforce. Visualforce and Aura are the opposite extreme: effectively zero portable surface. LWC sits in between — a standard Web Component shape wrapped around Salesforce-specific data APIs. This is the one dimension where React's advantage over all three predecessors is unambiguous and large, not a close call.

## What developers should learn now — without assuming the conclusion in advance

- **Learn deeply, for new development**: LWC remains the right default for anything that needs to live *inside* Lightning pages (record pages, App Builder composition, native Lightning Data Service/UI API integration) — nothing else in this comparison can do that, and Multi-Framework's own embedding path for that use case is still Beta.
- **Learn, with eyes open about current rough edges, for standalone/portable apps**: React via Salesforce Multi-Framework is real, current, GA, and — as verified end-to-end in this project — fully functional in production. Budget real time for npm/Vite/CLI tooling friction that has nothing to do with Salesforce logic, get the `CustomApplication`/`PermissionSet` metadata exactly right (diff against a freshly generated `reactinternalapp` template if in doubt), and validate custom Apex REST integrations against a deployed org rather than the local dev-preview tool.
- **Still need to understand, because production orgs run on it**: Aura. It is not where new development should start, but it is fully supported, coexists with LWC, and a working Salesforce developer will maintain and extend existing Aura code for years yet.
- **Still need to understand, for the same reason, at a shallower depth**: Visualforce. Lowest priority for new skill investment of the four, but "legacy" here means "present in enterprise orgs," not "broken" or "going away."

## What must an experienced Salesforce developer understand to maintain existing enterprise orgs, vs. what's worth learning deeply for new work

These are different questions, and this project deliberately keeps them separate:

- **To maintain what's already in production**: Visualforce's controller-extension/view-state model, and Aura's component/controller/helper split and manual state-attribute pattern, are both things a working Salesforce developer will encounter and must be able to read and safely modify, indefinitely. Neither is going away from existing orgs regardless of what's recommended for new work.
- **To build new things well today**: LWC for anything living inside Lightning; React via Multi-Framework is a legitimate, current option specifically for standalone or portable apps, evaluated here on its actual current merits and rough edges, not as a wholesale replacement for LWC — this project makes no such claim, and Salesforce's own documentation doesn't either.

## Known limitations of this experiment

- No performance benchmarks were run or are claimed anywhere in this repository. All comparisons are of code volume, structure, tooling, and developer experience, not speed.
- One org, one AI coding agent, one moderately-sized feature, one point-in-time toolchain snapshot (CLI/npm/package versions recorded above). This is a controlled, like-for-like comparison, not a statistically representative sample of Salesforce development at large — the local dev-proxy 401 in particular is reported as tied to the specific tool versions recorded above, not as a permanent characteristic of the platform.
- The AI-authored-code caveat applies throughout: every class, component, and test in this repository was written by an AI coding agent and should be reviewed the same way any AI-generated code should be before being treated as production-ready — see `results/ai-experiment-log.md` for the specific mistakes this project's own agent made and how each was caught.
