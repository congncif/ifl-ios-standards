# Compatibility and Migration

Status: Standards `1.0.0-rc.1` candidate policy

## Compatibility contract

The Standards define semantic architecture and engineering obligations, not one provider, UI framework,
package manager, build graph, or organization policy. Compatibility means that an adopter can apply the
selected Canon Profiles and preserve their Rules through a documented adapter or project binding. It
does not imply an unstated minimum iOS version, Xcode version, Boardy version, vendor commitment, legal
classification, security threshold, or support window.

## Provider compatibility

| Provider | Supported operating model |
|---|---|
| Claude Code | Claude plugin metadata, `${CLAUDE_PLUGIN_ROOT}` references, Skills/agents, and provider-native task, delegation, tool, and approval state. |
| Codex | Codex plugin metadata, plugin-root-relative resolution of the same bundled standards, Skills/subagents, and provider-native task, tool, and approval state. |

Both providers consume the same Canon and derived documents. Provider syntax and available native
capabilities may differ; those differences must not change architectural meaning or introduce a second
workflow contract. When delegation is unavailable, the same approved plan may run inline. Neither
provider requires a pack-owned verifier, receipt/manifest chain, or custom state engine.

## Architecture and UI Profiles

| Context | Profile selection and compatibility |
|---|---|
| Any governed project | `core` applies. It is pattern-, UI-, and build-system-neutral. |
| Boardy/VIP project or module | Add `boardy-vip`; it extends Core with Boardy lifecycle, IO, composition, communication, and VIP obligations. Boardy is optional outside that scope. |
| UIKit rendering | Add `uikit`; UIKit remains a rendering adapter and uses the shared presentation/domain boundaries. |
| SwiftUI rendering | Add `swiftui`; SwiftUI remains a rendering adapter with its Canon-defined state and isolation boundaries. |
| Mixed UIKit/SwiftUI product | Apply both UI Profiles to their respective surfaces; shared business and presentation meaning remains framework-independent. Add `boardy-vip` only where Boardy/VIP is used. |

The authoritative selections are the Profile files under `standards/canon/profiles/` and their mapped
Rules. UI guidance does not require a UIKit-to-SwiftUI migration, and adopting Core does not require
Boardy. See ADR-0008 and ADR-0009 for the rendering-adapter decisions.

## Build-system and dependency-manager compatibility

Architecture concepts are expressed as targets/modules and dependency direction. A consuming repo binds
those concepts to CocoaPods, SwiftPM, Bazel, or a documented combination. No manager may reverse Canon
dependency direction or make implementation targets public to consumers.

Manager-specific examples and scaffolders are capability-specific conveniences, not universal mandates
or evidence of feature parity. Projects keep their own workspace, scheme, target labels, module roots,
and build/test commands in `CLAUDE.md`, `AGENTS.md`, or equivalent project bindings. See
`standards/specs/PACKAGE_MANAGER.md` for the boundary and `standards/enterprise/supply-chain-legal.md`
for organization-owned dependency governance.

## Migration from `0.18.x`

Migration is an explicit adoption review, not a forced framework or build-system rewrite:

1. Update the installed pack through the provider's normal installation mechanism and keep project
   bindings for workspace, scheme, simulator, module root, build system, and commands project-owned.
2. Select `core` plus only the applicable `boardy-vip`, `uikit`, and/or `swiftui` Profiles. Record any
   project-specific interpretation in project bindings; do not fork Canon definitions.
3. Map existing architecture guidance to Canon Rule IDs and accepted ADR decisions. Treat old specs,
   Skills, agents, templates, and examples as derived guidance where they overlap Canon.
4. Retain CocoaPods, SwiftPM, Bazel, or hybrid wiring if it preserves the canonical target boundaries;
   `1.0.0-rc.1` does not require a dependency-manager migration.
5. Bind security, privacy, legal, performance, accessibility, retention, and other organization-owned
   values to the actual human-owned policies. Do not copy placeholder or invented values into adoption
   documentation.
6. Give every temporary deviation an owner, approving authority, compensating controls, expiry, and
   remediation plan as required by `standards/GOVERNANCE.md`.
7. Run the consuming repository's normal tests when migration changes executable code. Documentation,
   metadata, and binding-only adoption are assessed in the approved plan's single final joined AI review;
   they do not require fabricated runtime evidence.

Existing `0.18.x` projects are not non-conforming solely because they use UIKit, Boardy, CocoaPods,
SwiftPM, Bazel, mixed UI, or provider-specific commands. Conformance depends on the selected Profiles,
canonical boundaries, project bindings, and disposition of actual gaps.

## Compatibility changes

Classify compatibility changes, deprecations, removals, and exceptions under
`standards/GOVERNANCE.md`. A derived document cannot silently drop support or add a new minimum. Any
such material decision requires the governed Canon/ADR change and migration guidance.
