# iOS Standards Specs

These specs explain how to apply the IFL iOS Standards to modular iOS work. They are derived guidance:
Canon owns current obligations and the selected Profiles determine applicability.

## Start here

1. Read `../GOVERNANCE.md` for authority, decision rights, change classes, deprecation, and exceptions.
2. Read `../COMPATIBILITY.md` for provider, Boardy/UIKit/SwiftUI, build-system, and `0.18.x` migration
   boundaries.
3. Select `core` plus only the applicable Profiles from `../canon/profiles/`.
4. Bind workspace, scheme, simulator, module root, build system, commands, and organization-policy
   references in the consuming repo's `CLAUDE.md`, `AGENTS.md`, or equivalent project configuration.
5. Load the smallest relevant spec set below. A spec, Skill, agent, template, example, or scaffolder
   cannot override Canon.

## Task routing

Use `${CLAUDE_PLUGIN_ROOT}/standards/specs/...` from Claude Code. Under Codex, resolve the same paths
relative to the plugin root.

| Goal | Load |
|---|---|
| Understand authority or evolve the Standards | `../GOVERNANCE.md` → `../canon/adrs/ADR-0001-standards-authority-and-evolution.md` |
| Assess provider/framework/build compatibility or migrate `0.18.x` | `../COMPATIBILITY.md` → `PACKAGE_MANAGER.md` |
| Pick a Board/profile/bus/resource pattern | `DECISION_TREES.md` |
| Adopt in a legacy project | `BROWNFIELD_MIGRATION.md` → `ADOPTION.md` |
| Stand up a new project | `GREENFIELD_SETUP.md` |
| Understand architecture and layering | `ARCHITECTURE.md` → `LAYERING.md` |
| Choose a dependency or bind a package manager | `SDK_FIRST.md` → `PACKAGE_MANAGER.md` |
| Create a module and public IO | `MODULE_CREATION.md` → `IO_INTERFACE.md` |
| Build a Boardy/VIP UI or non-UI board | `MICROBOARD_UI.md` or `MICROBOARD_NONUI.md` |
| Implement VIP components | `VIP_COMPONENTS.md` |
| Wire board communication/navigation | `COMMUNICATION.md` → `CONTEXT_NAVIGATION.md` |
| Compose plugins or cross-module dependencies | `PLUGINS_INTEGRATION.md` → `CROSS_MODULE_DI.md` |
| Implement services/domain/infrastructure | `SERVICE_LAYER.md` → `LAYERING.md` |
| Write or select tests | `TESTING.md` → `../enterprise/modern-testing.md` |
| Review code | `REVIEW_PLAYBOOK.md` → `REVIEWER_CHECKLIST.md` |
| Refactor a module or public symbol | `REFACTOR_PLAYBOOK.md` |
| Debug a symptom or failure | `TROUBLESHOOTING.md` |
| Find skeleton code | `EXAMPLES.md` → one matching `EXAMPLES_*.md` |

## Profile selection

| Profile | Select when |
|---|---|
| `core` | Always. It carries universal authority, inward-dependency, and enterprise obligations. |
| `boardy-vip` | The governed scope uses Boardy lifecycle, IO, composition, communication, or VIP. |
| `uikit` | The governed scope renders through UIKit. |
| `swiftui` | The governed scope renders through SwiftUI. |

UIKit and SwiftUI may coexist. Boardy/VIP is optional outside Boardy scope. Profiles specialize Core;
they do not fork it. Use the Profile JSON files and mapped Rule IDs for the authoritative selection.

## Project binding contract

The specs use semantic placeholders such as Interface/contract target, Implementation/Plugins target,
module root, build command, and organization policy. A consuming repository supplies the concrete values.
CocoaPods, SwiftPM, Bazel, and mixed arrangements are valid when they preserve Canon boundaries; see
`PACKAGE_MANAGER.md`.

Do not put reusable project names, schemes, simulator models, module paths, legal values, security
thresholds, response windows, or publication authority in these specs. Human-owned organization policy
supplies those values. Missing authority is escalated, not guessed.

## Reading contract

- Canon → accepted ADR → active Rule/Profile → derived document is the precedence path.
- Follow links to detailed standards instead of copying their Rules into another spec.
- Treat code and build snippets as examples adapted through project bindings.
- Documentation and metadata use the approved plan's one final joined AI consistency review; executable
  project changes use the consuming repository's normal tests.
- CI, tags, publication, and external release remain DevOps/Release-owned and are not requirements of
  these specs.
