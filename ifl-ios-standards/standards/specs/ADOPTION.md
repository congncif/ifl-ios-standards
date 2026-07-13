# ADOPTION — bind Standards 1.0 to an iOS repository

This is derived adoption guidance. Canon Rules and selected Profiles are normative; accepted ADRs
explain their decisions. Adoption never makes this guide, a template, or a project checklist a second
Rule source.

Use `GREENFIELD_SETUP.md` for a new app and `BROWNFIELD_MIGRATION.md` for an existing app. Standards
1.0 is provider-, UI-, orchestration-, package-manager-, and build-system-neutral. Boardy is optional.

## 1. Declare the adoption scope

An adoption record identifies exactly what is being governed:

- repository/product and owning team;
- included apps, extensions, modules, targets, or semantic slices;
- explicit exclusions and their owners;
- current baseline and migration source, if any;
- selected Canon Profiles and enterprise chapter applicability;
- project-policy bindings and human owners;
- conformance target and review date; and
- exception/transitional records.

Do not claim repository-wide adoption from one migrated feature. Expand the declared scope only when
the newly included surface has been assessed.

## 2. Select Profiles by actual architecture

| Project surface | Profile selection |
|---|---|
| Every adopted scope | `core` — always selected |
| Boardy/VIP module or flow | `boardy-vip` for that surface only |
| UIKit rendering surface | `uikit` |
| SwiftUI rendering surface | `swiftui` |
| Mixed UIKit/SwiftUI product | both UI Profiles, each applied to its real surfaces |

Core does not imply Boardy. A Boardy adapter does not move Boardy into Domain or Application policy.
UIKit and SwiftUI may coexist; equivalent domain input produces equivalent display-ready semantic state.

## 3. Record enterprise applicability and policy owners

Load a chapter when its trigger intersects the declared scope. Record `applicable`, `not applicable`
with rationale, or an owned transitional/exception status at Rule level; do not mark an entire chapter
N/A merely because no value has been bound yet.

| Chapter | Typical applicability trigger | Project-owned binding/authority |
|---|---|---|
| Swift 6 concurrency | executable Swift isolation, tasks, callbacks, shared state | language-mode destination, migration owner, actor/isolation policy |
| SwiftUI production | any SwiftUI rendering/navigation/state surface | UI architecture and navigation owner |
| Data lifecycle | business/user data is stored, cached, synchronized, migrated, or deleted | classification, retention/deletion, backup/offline owner |
| Mobile security | authentication material, sensitive data, network trust, WebView/input, secrets | security owner, threat/risk acceptance authority |
| Privacy compliance | collection, tracking, required-reason API, consent, disclosure, manifest | privacy/legal owner and approved disclosure source |
| Accessibility/global readiness | any user-facing UI or localized product behavior | accessibility/product/localization owner and target policy |
| Observability/operability | logs, events, metrics, crash data, correlation, buffering | telemetry owner, redaction/privacy policy, incident ownership |
| Modern testing | executable behavior, public contract, regression, accessibility/performance assertion | repository test commands and quality owner |
| Performance/resilience | production startup/frame/memory/energy/network/offline/retry behavior | product SLO/budget owner and measurement environment |
| Supply chain/legal | third-party/internal dependencies, artifacts, notices, licenses, vulnerabilities | dependency/security/legal owners and approved inventory |

The plugin provides no organization-specific numeric threshold, vendor allowlist, retention period,
legal conclusion, contact, SLO, deployment target, or release sign-off. Bind those to real policies and
named owners; a missing material decision is not filled by AI.

## 4. Conformance states

Use one of these states for the declared scope:

| State | Meaning |
|---|---|
| **Full conformance** | Every applicable Rule in the selected Profiles/chapters is satisfied; policy bindings are owned; no unresolved exception or transition is hidden. |
| **Partial adoption** | Only explicitly named modules/slices are assessed. Those slices may be conforming, but no claim is made for excluded scope. |
| **Transitional conformance** | A destination Rule is not yet fully met under an approved, time-bounded migration with owner, milestones, risk, compensating controls, and review/expiry. |
| **Not applicable** | The Rule's trigger is absent in the declared scope, with a concrete rationale and reviewer. |
| **Approved exception** | A deliberate deviation has approving authority, rationale, risk, compensating controls, remediation/exit condition, and expiry/review date. |
| **Non-conforming** | An applicable Rule is unmet without an approved transition/exception; it remains visible work or a release/adoption blocker under project policy. |

“Standards installed,” “Boardy used,” “tests pass,” and “AI review complete” are not conformance states.
Conformance is scoped applicability plus actual Rule disposition.

## 5. Transitional Swift concurrency

Complete Swift 6 isolation remains the destination where the selected Rule requires it. An existing
repository may declare transitional conformance rather than pretending that incremental migration is
already complete. Record:

- current language/concurrency mode and affected targets;
- destination and responsible owner;
- known isolation/Sendable gaps and risk;
- ordered milestones and migration boundary for newly changed code;
- temporary compatibility annotations or controls and their removal condition; and
- review date/expiry.

A transition cannot permanently weaken the destination Rule. New violations outside the declared
migration boundary are non-conforming unless separately dispositioned.

## 6. Architecture contract for every adopted slice

1. Public contracts and implementation remain separate; consumers do not import another feature's
   implementation target.
2. Domain and Application policy depend inward and consume outward capabilities through inward-owned
   protocols (`CORE-DEP-001`…`003`).
3. Boardy, UIKit, SwiftUI, networking, persistence, and vendor/utility frameworks stay in their
   selected outward adapters.
4. Typed intent carries public behavior; do not replace it with string routes, dictionaries,
   notifications, or unowned callback payloads.
5. A Presenter or equivalent testable mapper owns raw/domain-to-display derivation and formatting.
6. A humble View renders display-ready state, may branch on already encoded presentation state, and
   owns only minimal ephemeral UX mechanics such as focus, highlight, gesture, disclosure, animation,
   scroll, geometry, or visual interpolation. It does not compute business or product-facing values.

## 7. Project bindings

Keep project-owned values in the consuming repository's `CLAUDE.md`, `AGENTS.md`, or referenced
configuration—not in this plugin:

- workspace/project, targets/schemes, destinations, module roots, and package manager;
- canonical build/test/format/generation/launch commands and CI owner;
- default Brain-Flow mode, scoped local Git authority, and external/release authority;
- resume/handoff location and final finding-disposition authority;
- deployment/toolchain support policy;
- security/privacy/accessibility/observability/data/supply-chain owners;
- project exceptions/transitions and their expiry; and
- release qualification/sign-off policy.

Mode and authority are separate. A default of `auto` does not grant commit, push, tag, publish,
installation, deployment, or release.

## 8. Adopt by semantic slice

A semantic slice is one complete observable behavior, not a file, layer, agent assignment, or
generated artifact.

1. Declare its entry, user-visible behavior, outputs, dependencies, failure behavior, and applicable Rules.
2. Define typed public contracts and module ownership before changing implementation.
3. Select only the real pattern/UI Profiles and enterprise chapters.
4. Compose concrete adapters behind inward-owned contracts.
5. Route one real caller while retaining a practical cutover/rollback path.
6. Run only repository-owned executable signals warranted by changed behavior; documentation-only
   adoption has no build/test gate.
7. Record conformance, transition, N/A, and exception dispositions with owners.
8. Remove the legacy path only after callers/outputs move and rollback conditions are satisfied.

Brownfield work uses a strangler migration only while an explicitly owned slice needs the bridge.
Greenfield work starts with one vertical slice and expands its declared adoption scope deliberately.

## 9. Brain-Flow operation

Use `../process/full-auto-operating-model.md`:

- co-working uses human Requirement/Plan decisions and includes the user in final disposition when requested;
- eligible auto uses independent AI gates and runs without routine confirmation;
- both execute one complete plan, use semantic commits when authorized, and run one frozen-candidate
  joined final AI review; and
- full auto ends at engineering completion/release readiness, never implicit publication.

Do not add verifier/lint/smoke scripts, workflow receipts/digests, custom kernels, duplicate CI, or
provider-independent state. The consuming repository owns executable commands and CI.

## 10. Adoption review checklist

- [ ] Declared adoption scope and exclusions are exact.
- [ ] `core` plus only actual Boardy/UI Profiles are selected.
- [ ] All ten enterprise chapters have scoped applicability dispositions.
- [ ] Organization policy values have real sources and named human owners.
- [ ] Full/partial/transitional/N/A/exception states are explicit and not conflated.
- [ ] Domain/Application remain framework-neutral and concrete dependencies stay outward.
- [ ] UIKit/SwiftUI Views receive display-ready state and remain humble.
- [ ] Brownfield slices have cutover, rollback, transition/exception owner, and review/expiry.
- [ ] Executable changes used repository-owned risk-relevant signals; docs-only work did not invent one.
- [ ] Brain-Flow mode and each Git/external/release authority are bound separately.
- [ ] No obsolete tool-specific adoption process or parallel workflow-state system is active.

## References

- `BROWNFIELD_MIGRATION.md` — strangler migration and 0.18.x transition.
- `GREENFIELD_SETUP.md` — first vertical slice in a new app.
- `ARCHITECTURE.md`, `LAYERING.md`, `IO_INTERFACE.md` — boundaries and typed contracts.
- `../canon/profiles/` and `../canon/rules/` — normative applicability and Rules.
- `../process/full-auto-operating-model.md` — provider-native operating contract.
- `../process/lean-verification.md` — plan-scale execution and one final review.
