# Compatibility, Adoption, and Migration

Status: unpublished Standards `1.0.0-rc.5` working candidate

Published install baseline: `v1.0.0-rc.1`; this document is not a direct GA or candidate-publication claim

## Compatibility contract

The Standards define semantic architecture and enterprise engineering obligations, not one provider,
architecture pattern, UI framework, package manager, build graph, or organization policy. Core is the
profile-neutral baseline. An adopter adds only the Profiles and enterprise chapters applicable to its
product and change impact, then binds organization-owned values to named human owners.

Compatibility means those selected Canon Rules can be preserved through documented project adapters
and bindings. It does not imply an unstated iOS/Xcode/Swift/Boardy/vendor minimum, legal classification,
security threshold, support window, or field-qualified GA status.

## Provider compatibility

| Provider | Supported operating model |
|---|---|
| Claude Code | Claude plugin metadata, plugin-root references, Skills/agents, and provider-native task, delegation, tool, approval, and resume state. |
| Codex | Codex plugin metadata, plugin-root-relative bundled standards, Skills/subagents, and provider-native task, tool, approval, and resume state. |

Both providers consume the same Canon and operating contract. Syntax and native capabilities may
differ but cannot change architecture, conformance, or authority meaning. When delegation is
unavailable, an eligible approved plan may continue inline. Neither provider requires a pack-owned
kernel, verifier, receipt/manifest chain, CI system, or custom state engine.

The current candidate must complete the provider/profile/build-system qualification matrix in
`RELEASE.md` before a GA compatibility claim. A listed provider or adapter that has not completed its
required row is `not qualified`, not silently inferred as GA-supported.

## Profile-neutral architecture and UI adoption

| Context | Applicable selection |
|---|---|
| Any governed project | Select `core`; it is pattern-, UI-, provider-, and build-system-neutral. |
| Boardy/VIP module | Add `boardy-vip` for that scope; Boardy remains an outward orchestration/presentation profile around framework-neutral Domain/Application policy. |
| UIKit rendering | Add `uikit`; UIKit is a rendering adapter using shared inward-owned meaning. |
| SwiftUI rendering | Add `swiftui`; SwiftUI is a rendering adapter with selected state/isolation Rules. |
| Mixed UIKit/SwiftUI product | Apply both UI Profiles only to their respective surfaces; add Boardy only where used. |
| Pattern other than Boardy | Keep Core and selected UI/enterprise obligations; bind the pattern adapter locally without treating Boardy guidance as universal. |

Profile files under `standards/canon/profiles/` and their active Rule mappings are authoritative. UI
adoption does not require a UIKit-to-SwiftUI migration. Core adoption does not require Boardy, and a
Boardy module does not permit Boardy or utility frameworks inside Domain/Application policy.

## Conformance semantics

| State | Meaning and claim boundary |
|---|---|
| **Full** | Every applicable active Core/Profile Rule and selected enterprise policy binding is satisfied; owners are recorded; no exception is expired. The claim names the assessed product/module scope and candidate/version. |
| **Partial** | Only a declared subset is assessed/satisfied. The record lists included and excluded scope, non-applicable items, known gaps, owners, and consequences. It cannot be presented as whole-product or organization-wide conformance. |
| **Transitional** | Time-bounded partial conformance with an approved migration owner, milestones, expiry, and target state. Strict Swift concurrency may be a staged destination for existing code, but the transition is not a permanent weakened standard. |
| **Non-applicable** | A Profile, Rule, or chapter is outside the declared product/change impact. Record rationale and owner; this is not an exception. |
| **Exception** | A temporary approved deviation governed by `GOVERNANCE.md`, including risk, compensating controls, approving owners, expiry, and remediation. |

The Consuming-team Conformance Owner owns the claim. AI may assess evidence and identify gaps but
cannot decide organization-owned policy, approve an exception, or promote partial/transitional status
to full. Conformance to this working candidate is not a GA claim.

## Build-system and dependency-manager compatibility

Architecture concepts are expressed as modules/targets, public contracts, adapters, composition roots,
and inward dependency direction. A consuming repository binds those concepts to CocoaPods, SwiftPM,
Bazel, or a documented combination. No adapter may reverse Canon dependency direction, expose an
implementation target as a consumer contract, or introduce Boardy into framework-neutral policy.

Manager-specific examples and scaffolders are conveniences, not universal mandates or proof of field
qualification. Repositories keep workspace, scheme, target labels, module roots, and normal build/test
commands in `CLAUDE.md`, `AGENTS.md`, or equivalent bindings. Executable migrations use only their
risk-relevant ordinary signals; documentation/binding-only adoption has no artificial build/test gate.

## Migration from `0.18.x`

Migration is an explicit adoption review, not a forced pattern, UI, provider, or build-system rewrite:

1. Keep the currently published RC1 install unless a separately authorized candidate artifact/source is
   provided for qualification; do not infer publication from this working-candidate document.
2. Inventory current modules, boundaries, provider bindings, build graph, policy owners, and known
   deviations.
3. Select `core` plus only applicable `boardy-vip`, `uikit`, `swiftui`, and enterprise chapters. Do not
   fork Canon or load Boardy by default.
4. Map existing obligations to Canon Rule IDs and accepted ADRs. Treat overlapping legacy specs,
   Skills, agents, templates, and examples as derived guidance.
5. Declare full, partial, or transitional scope. Give each gap/exception an owner, approving authority,
   compensating controls where relevant, expiry, and remediation plan.
6. Retain CocoaPods, SwiftPM, Bazel, or hybrid wiring when it preserves canonical boundaries; the candidate does
   not require a package-manager or UI-framework migration.
7. Execute one approved migration plan. Use focused ordinary tests only where product executable code
   changes, semantic commits when authorized, and one joined final AI consistency review.
8. Report engineering completion separately from qualification, publication, installation, rollout,
   and any future GA decision.

Existing projects are not non-conforming merely because they use UIKit, SwiftUI, Boardy, another
pattern, CocoaPods, SwiftPM, Bazel, mixed UI, or provider-specific commands. The result depends on
selected Profiles, actual boundaries, declared conformance scope, organization policy bindings, and
owned disposition of real gaps.

## Compatibility evolution

Classify compatibility changes, deprecations, removals, and exceptions under `GOVERNANCE.md`. A
derived document cannot silently add/drop support, introduce a minimum, or claim field qualification.
Material changes require governed Canon/ADR decisions, migration guidance, a new candidate, and the
qualification/sign-offs in `RELEASE.md`. Until those complete, `1.0.0-rc.5` remains an unpublished
working candidate and the marketplace remains on published RC1.
