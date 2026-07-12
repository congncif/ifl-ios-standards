<!-- Created by claude-opus-4-7 on 2026-05-23 -->
# POLICY: Package Manager

> Boundary spec — defines which package manager this pack assumes today, what the rest of the spec corpus may and may not say about it, and the open ADR slot for future managers.

## Decision (current — pack `0.4.x`+)

**Pinned package manager: CocoaPods.**

All worked examples, podspec snippets, `s.dependency` lines, `Podfile` blocks, and `pod install` instructions in this pack assume CocoaPods. The 2-target IO + Plugins module split is described using CocoaPods semantics (`{Module}.podspec` for IO, `{Module}Plugins.podspec` for Plugins).

This is a **soft pin**, not a permanent decision. See "Open ADR" below.

## Why CocoaPods (today)

- **QC baseline + Boardy ecosystem ship CocoaPods.** Switching managers would invalidate every working example in the corpus before the pack stabilizes.
- **Resource bundles + Obj-C bridging headers** common in SDK adapters are simpler to express in podspec than in `Package.swift`.
- **Local-path development** (`pod '{Module}', :path => '...'`) gives the 2-target IO+Plugins split clean cross-module compile-time isolation without ceremony.
- **`s.dependency` is a single semantic concept** that maps 1:1 to the import-and-extend ServiceMap pattern — `s.dependency '{OtherModule}'` IS the cross-module contract.

This is rationale for the current pin only — none of the above is an argument against future managers.

## Open ADR slot

The following alternative managers are **explicitly out of scope for `0.x`** but reserved as future ADRs:

| Manager | ADR ID (reserved) | Why it might matter |
|---|---|---|
| SwiftPM | `ADR-PM-001` | First-party Apple tooling; better Xcode integration since Xcode 13; modules-as-targets eliminates the podspec layer entirely. |
| Bazel | `ADR-PM-002` | Hermetic builds + remote caching at scale; mono-repo workflows; finer-grained target graph than either CocoaPods or SwiftPM. |
| Mixed / hybrid | `ADR-PM-003` | Real-world apps may keep CocoaPods for legacy SDKs and adopt SwiftPM for new modules. Boundary between the two needs explicit rules. |

When an ADR for any of these opens, it MUST extend (not replace) this policy and SHOULD document:

1. Trigger — what changed that makes the new manager viable / necessary.
2. Migration scope — full corpus rewrite, parallel examples, or per-module opt-in.
3. Compatibility window — overlap period during which both managers are supported.
4. Architecture-review impact — what changes for dependency, visibility, and BoardID rules.
5. Bin-script impact — `new-module.sh` / `new-board.sh` flag surface.

No ADR is open today.

## Boundary contract — what specs may and may not say

The core architecture (Boardy + VIP + 2-target split + Microboard + Composable + ActivationBarrier + Per-Activation Resources + Extensible Provider) is **package-manager-agnostic in concept**. The current pack uses CocoaPods to *illustrate* the architecture, not to *define* it.

### Layer 1 — core pattern specs (MUST stay generic in prose)

The following specs describe architectural concepts, and the **prose** should refer to "IO module" / "Plugins module" / "Interface module" / "Implementation module" rather than "IO podspec" / "Plugins podspec":

- `ARCHITECTURE.md`
- `IO_INTERFACE.md`
- `LAYERING.md`
- `MICROBOARD_UI.md` / `MICROBOARD_NONUI.md`
- `VIP_COMPONENTS.md`
- `COMMUNICATION.md`
- `BOARDY_FOUNDATIONS.md`
- `BUS_PATTERNS.md`
- `COMPOSABLE_BOARD.md`
- `ACTIVATION_BARRIER.md`
- `PER_ACTIVATION_RESOURCES.md`
- `EXTENSIBLE_PROVIDER.md`
- `SERVICE_LAYER.md`
- `SDK_FIRST.md`
- `CROSS_MODULE_DI.md`

**Code blocks in Layer-1 specs MAY contain `s.dependency '…'` / podspec snippets** as concrete illustration, but each code block SHOULD be preceded by prose that names the concept generically (e.g. *"Cross-module dep — in CocoaPods this is expressed via:"*) so the same passage stays readable when another manager is introduced.

### Layer 2 — operational specs (MAY be CocoaPods-specific until an ADR opens)

The following specs describe the *current* operational workflow and are allowed to be CocoaPods-specific without disclaimer:

- `MODULE_CREATION.md` (Podfile + pod install + podspec scaffolding)
- `ADOPTION.md` (checklist mentions podspec/package target)
- `EXAMPLES_*.md` (all example skeletons may show podspec dep blocks)
- `PLUGINS_INTEGRATION.md` (LauncherPlugin wiring — references `{Module}Plugins` import which is the Plugins podspec name)

These specs accept the current pin and do not need to abstract over future managers. They will be revised when an ADR opens.

### Forbidden leaks

Even within Layer-1 specs:

- ❌ A rule like "MUST use `:path => ...` syntax" → this is a CocoaPods-specific rule and belongs in `MODULE_CREATION.md` or a future SwiftPM-equivalent, not in `ARCHITECTURE.md`.
- ❌ "The Plugins podspec MUST declare `s.dependency 'Boardy'`" stated as an architectural invariant → restate as "The Plugins module MUST link Boardy"; the podspec sentence belongs in `MODULE_CREATION.md`.
- ❌ Hardcoded path conventions like `{ModuleRoot}/{Module}/{Module}.podspec` baked into pattern-spec prose → cite `MODULE_CREATION.md` for layout.

When in doubt: **if swapping to SwiftPM would invalidate the sentence, the sentence belongs in an operational spec, not a pattern spec.**

## Cross-module dep — manager-agnostic restatement

A "cross-module dep" in this pack means: *module A's Plugins target links module B's IO target, so module A's ModulePlugin can `import B` and call `motherboard.serviceMap.modB...`.*

| Manager | How this is expressed |
|---|---|
| CocoaPods (current) | `s.dependency 'B'` in `APlugins.podspec` + `pod 'B', :path => '...'` in `Podfile` |
| SwiftPM (future ADR) | `.target(name: "APlugins", dependencies: ["B"])` in `Package.swift` |
| Bazel (future ADR) | `deps = ["//modules/B:B"]` in `APlugins`' `BUILD.bazel` |

The architectural rule — "Plugins links IO, IO never links Plugins, IO never links sibling Plugins" — is identical across all three.

## Roadmap

| Pack version | Manager status |
|---|---|
| `0.x` (current) | CocoaPods pinned; no ADR open |
| `1.0` | Reassess. If no SwiftPM ADR has opened, re-affirm CocoaPods pin and document any boundary clean-ups discovered during `0.x`. |
| `1.x` | An ADR for an alternative manager MAY open here; first such ADR will define parallel-examples vs migration semantics. |
| `2.0` | If `1.x` opened an ADR, `2.0` is the earliest version where the pinned manager could change (major bump = adopter re-audit). |

No timeline is committed. The roadmap is shape-only.

## Adopter implications

- Adopter projects using CocoaPods: zero special action; the pack works out of the box.
- Adopter projects using a different manager today: the pack is **not** the right scaffolding source until an ADR for that manager opens. Adopter SHOULD fork the pack or maintain manager-specific overrides under `standards/local/` (convention TBD).
- Adopter projects mixing managers: out of scope until `ADR-PM-003` opens.

## How to escalate a manager change

If an adopter project needs (or wants) to drive an ADR for a non-CocoaPods manager:

1. Open an issue against the pack titled `ADR-PM-XXX — {manager}` referencing this spec.
2. Provide: scope (single module / whole adopter / all adopters?), trigger, and a draft of which Layer-1 spec prose would need to flip from CocoaPods-illustrated to dual-illustrated.
3. Do NOT submit a PR rewriting all examples first — the boundary contract is the artifact under review, not the code.

## References

- `ARCHITECTURE.md` (the architecture this policy preserves across managers)
- `MODULE_CREATION.md` (operational spec — CocoaPods-specific by design)
- `rules/SPEC_CONTRACT.md` (this spec is exempt from the 12-section format — see Exemptions)
- `CHANGELOG.md` `0.5.0` entry (introduction of this policy)
