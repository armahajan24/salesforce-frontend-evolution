# Framework Comparison — Visualforce vs. Aura vs. LWC vs. React (Multi-Framework)

This document compares all four implementations across the dimensions that matter for a real engineering decision. It does **not** assign an overall winner, and it does **not** claim React replaces LWC — the two solve different problems (see "Current best-fit scenarios" at the end). Every specific claim here is backed by either the code in this repository, a live test run, or currently-verified Salesforce documentation; see [findings.md](findings.md) and [../results/comparison.md](../results/comparison.md) for the underlying evidence.

## Data access

| | Visualforce | Aura | LWC | React (Multi-Framework) |
|---|---|---|---|---|
| Read path | Controller extension → shared Apex service, in-process call | `$A.enqueueAction` → shared `@AuraEnabled` Apex | Imperative Apex (composite read) — shared with Aura | `dataSdk.fetch()` → dedicated Apex REST endpoint |
| Write path | Same Apex service, in-process | Shared `@AuraEnabled` Apex method | `lightning/uiRecordApi.updateRecord` (Lightning Data Service) | `dataSdk.fetch()` PATCH → same Apex REST endpoint |
| Can call `@AuraEnabled`/`@wire`/`lightning/*`? | N/A (VF has its own controller model) | Yes — native | Yes — native | **No** — not available outside the LWC/Aura runtime |
| Can call custom Apex at all? | Yes, directly | Yes, via `@AuraEnabled` | Yes, via `@AuraEnabled` or LDS | **Yes** — via Apex REST (`@RestResource`), called through the Data SDK. Different plumbing, same platform, same custom logic. |
| GraphQL used in this project? | No | No | No (imperative Apex chosen instead — see architecture.md) | No (Apex REST chosen instead — see architecture.md and findings.md for why) |

## State management

| | Visualforce | Aura | LWC | React |
|---|---|---|---|---|
| Where state lives | Server-side controller, between full/partial page requests | Component attributes, client-side | Class fields + getters, client-side | `useState`/`useMemo`, client-side |
| Derived/computed state | Recomputed controller getters per request | Manually maintained boolean attributes (`hasError`, `hasDashboard`, etc.) because Aura's expression language can't do compound conditionals inline | Plain JS getters (`get hasError() { return !!this.errorMessage; }`) | `useMemo` (explicit memoization) |
| Boilerplate | Low (no client state to manage, but a full-page mental model) | **Highest of the four** — hand-maintained parallel booleans | Low | Low |

## Salesforce platform integration

| | Visualforce | Aura | LWC | React |
|---|---|---|---|---|
| Sharing/FLS/CRUD enforcement | Same shared Apex layer (`WITH USER_MODE`, `AccessLevel.USER_MODE`) | Same shared Apex layer | Same shared Apex layer | Same shared Apex layer, reached via REST instead of `@AuraEnabled` |
| Runs inside the Lightning Component Framework? | No | Yes | Yes | **No** — runs as an independent web app hosted on Salesforce infrastructure |
| Native platform identity/session handling | Standard Salesforce session | Standard Salesforce session | Standard Salesforce session | Data SDK (`createDataSDK()`) handles auth/CSRF/session automatically when deployed; **the local dev-preview tool's proxy has a reproducible gap authenticating Apex REST specifically — see findings.md** |

## App Builder compatibility

| | Visualforce | Aura | LWC | React |
|---|---|---|---|---|
| Droppable onto a Lightning record/app/home page via App Builder | No | Yes | **Yes — the only one of the four with zero extra metadata required** | No (launches as its own app) |
| Standalone app launch | Direct page URL | Standalone `.app` (used in this project as the launcher) | No standalone URL — requires a host page or Aura/LWC wrapper for preview | `CustomApplication` + `UIBundle`, opens from App Launcher at its own `*.my.salesforce.app` URL |
| Embeddable inside an existing Lightning page as a component | No | Yes (native) | Yes (native) | Only via `lightning-ui-embedding` microfrontend iframe — **currently Beta** |

## Lightning-native capabilities

| | Visualforce | Aura | LWC | React |
|---|---|---|---|---|
| Lightning Data Service | No | Available, not used here | **Used here** for the Stage update | Not available |
| Lightning base components (`lightning-*`) | No | Yes | Yes | Not available |
| UI API GraphQL wire adapter | No | No | Available, not used here (imperative Apex chosen instead) | Available via `dataSdk.graphql` (not used in this implementation) |

## Standard web technology usage

| | Visualforce | Aura | LWC | React |
|---|---|---|---|---|
| Underlying tech | Proprietary markup language, server-rendered | Proprietary component model wrapping HTML/CSS/JS | **Standard Web Components** (native class syntax, Shadow DOM, ES modules) wrapping Salesforce-specific data APIs | **Ordinary React/JSX/TypeScript** — the only Salesforce-specific surface is the ~109-line data-access file |
| Would a generic web developer (non-Salesforce) recognize the syntax? | Barely | Partially | Mostly | Almost entirely |

## Testing

| | Visualforce | Aura | LWC | React |
|---|---|---|---|---|
| Dedicated client-side test tool | None idiomatic | None idiomatic (Aura's own test framework is legacy) | `@salesforce/sfdx-lwc-jest`, pre-wired into standard SFDX projects | Vitest + Testing Library — standard React tooling, not Salesforce-specific |
| Runs against real org data? | Confidence via Apex tests (real org) + live browser check | Same | Jest runs offline (jsdom); confidence in real rendering came from a **live browser check that caught a bug the passing Jest suite missed** | Vitest runs offline (jsdom); confidence in the real Apex REST integration required a **live, deployed-org check** — see findings.md |
| E2E tooling provided by the platform | None | None | None | Playwright, pre-configured by the official template (not exercised against the real org in this project) |

## Tooling & local development

| | Visualforce | Aura | LWC | React |
|---|---|---|---|---|
| Local dev server | None — deploy to see changes | None | None (limited local preview) | `npm run dev` (Vite, hot reload) + `sf ui-bundle dev` (authenticated proxy to the real org) |
| Feedback loop | `sf project deploy start` each time | Same | Same | Faster once running, **but getting it running required resolving 3 npm/tooling issues in this project** (see ai-experiment-log.md) |
| Outside-Salesforce tooling dependency | None | None | None | Real — npm, Vite, Node version compatibility, transitive dependency resolution all matter |

## Deployment

| | Visualforce | Aura | LWC | React |
|---|---|---|---|---|
| Metadata type(s) | `ApexPage` | `AuraDefinitionBundle` | `LightningComponentBundle` | `UIBundle` + `CustomApplication` + `PermissionSet` |
| Build step before deploy | None | None | None | **Yes** — `npm run build`; the compiled `dist/` output is deployed, not source |
| CLI command | `sf project deploy start` (identical for all four) | Same | Same | Same |

## Dependency management

| | Visualforce | Aura | LWC | React |
|---|---|---|---|---|
| External package dependencies | None | None | None | Full npm dependency tree (`@salesforce/platform-sdk`, React, Vite, Tailwind, shadcn/ui, etc.) — real version-resolution risk, evidenced directly in this project (a version-skewed transitive dependency broke the production build once) |

## Portability outside Salesforce

| | Visualforce | Aura | LWC | React |
|---|---|---|---|---|
| Portable without rewrite | None | None | Partial — Web Component shape is portable, `lightning/*`/`@wire`/LDS are not | **High** — everything outside one small data-access file is ordinary React |

## Learning curve

| | Visualforce | Aura | LWC | React |
|---|---|---|---|---|
| For an experienced general web developer | Steep — a whole proprietary templating language and server-driven mental model | Steep — proprietary component model, manual state patterns | Moderate — standards-based, plus Salesforce-specific decorators/wire adapters | **Low if React is already known**; otherwise identical to learning React from scratch (Salesforce contributes very little extra) |
| Net-new material for a React developer specifically | Everything | Everything | Everything | Small and concentrated: Data SDK surface, UIBundle deployment model, the constraint list of what's unavailable |

## Maintenance considerations

| | Visualforce | Aura | LWC | React |
|---|---|---|---|---|
| Ongoing burden | Low complexity per page, but a shrinking pool of developers who know the syntax well | Verbose state handling adds ongoing edit friction | Lowest ongoing friction of the Lightning-runtime options | Depends on keeping the npm dependency tree healthy over time — a maintenance category the other three simply don't have |

## Migration considerations

| | Visualforce → other | Aura → other | LWC → other | React → other |
|---|---|---|---|---|
| Migrating *to* LWC | Full rewrite (different markup, different runtime) | Partial — Aura can host LWC (one direction only); logic often portable, markup is not | N/A | N/A (different application model, not a component swap) |
| Migrating *off* Salesforce entirely | Not practical | Not practical | Requires replacing `lightning/*`/LDS/`@wire` usage | **Practical for most of the codebase** — swap the data-access layer, keep the UI |

## Current best-fit scenarios

- **Visualforce**: maintaining existing pages in enterprise orgs. Not recommended for new development; this project does not claim it's "dead" — it's fully supported and present in real orgs today.
- **Aura**: same maintenance posture as Visualforce, one tier more capable (App Builder embedding, client-side reactivity). Salesforce's own guidance directs new work to LWC; this project's data doesn't contradict that, but Aura had the cleanest, error-free build of the four here.
- **LWC**: the right default for anything that needs to live inside Lightning — record pages, App Builder composition, native LDS/UI API integration. Nothing else in this comparison can do that.
- **React (Multi-Framework)**: a legitimate, current, GA option specifically for standalone or portable apps (internal tools, apps meant to eventually run outside Salesforce, teams with existing React investment) — not a substitute for LWC's in-Lightning-page role, which it structurally cannot fill today (App Builder embedding is Beta-only).

## What to learn deeply for new work, vs. what you must understand to maintain what already exists

These are different questions and this project answers them separately, deliberately:

- **New work**: LWC for anything inside Lightning; React via Multi-Framework for standalone/portable apps where the team has or wants React skills. Neither replaces the other — they target different deployment shapes.
- **Maintaining existing enterprise orgs**: Visualforce's controller-extension/view-state model and Aura's component/controller/helper/manual-state-attribute pattern are not optional knowledge for a working Salesforce developer, regardless of what's recommended for greenfield work. Both are fully supported and will remain in production orgs for years.
