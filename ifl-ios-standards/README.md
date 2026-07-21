# ifl-ios-standards

A dual-provider plugin packaging reusable **iOS engineering standards**: 9 Claude specialist agents,
21 skills including `enterprise-ios`, provider-native Brain Flow, Boardy/VIP task routing, ten
focused enterprise chapters, and thin build-system-neutral module/board source scaffolders.

> **Release status (2026-07-14):** this payload is Standards `1.0.0` General Availability. Public
> marketplace and installation references are pinned to immutable tag `v1.0.0`.

## What's inside

| Component | What it is |
|-----------|------------|
| `agents/` (9) | Claude uses the packaged `ios-*` specialists; Codex maps their responsibilities onto provider-native generic subagents with inline fallback |
| `skills/` (21) | **Brain stages** (pattern-neutral, provider-native): `brain-design`, `brain-architect`, `brain-plan`, `brain-execute`, `brain-testing`, `brain-review`, `brain-flow` (end-to-end automation) · **Boardy/VIP tasks**: router `boardy-vip` + `boardy-new-module`, `boardy-new-board`, `boardy-io-interface`, `boardy-communication`, `boardy-service-layer`, `boardy-plugin-composition`, `boardy-testing`, `boardy-review`, `boardy-refactor`, `boardy-troubleshoot`, `boardy-adopt` · **Enterprise iOS**: router `enterprise-ios` · `init` |
| `standards/` | Bundled reference: `rules/` (6), `brain/` (rulebook + patterns), `specs/` (44 incl. compact), ten focused `enterprise/` chapters, plan-scale process guidance, and `templates/portable-claude/` |
| `bin/` | `ifl-init` (seed CLAUDE.md/AGENTS.md), `ifl-new-module`, `ifl-new-board`; command-name invocation requires plugin `bin/` or the Codex shim directory to be on shell `PATH` |

## Activate

```bash
# every task type is also auto-detected by description — these are explicit entry points:
/ifl-ios-standards:boardy-vip          # router — read first, routes to the right skill/spec
/ifl-ios-standards:brain-flow          # automate the whole workflow: analyze → … → done
/ifl-ios-standards:enterprise-ios      # route enterprise concerns to the relevant chapter(s)
/ifl-ios-standards:boardy-new-module
/ifl-ios-standards:boardy-new-board
/ifl-ios-standards:boardy-review
# … boardy: :boardy-io-interface :boardy-communication :boardy-service-layer :boardy-plugin-composition :boardy-testing :boardy-refactor :boardy-troubleshoot :boardy-adopt
# … brain stages: :brain-design :brain-architect :brain-plan :brain-execute :brain-testing :brain-review
```

Or describe the iOS task and choose the matching skill family: `brain-*` for pattern-neutral flow,
`boardy-*` for Boardy/VIP projects, and `enterprise-ios` for Swift concurrency, SwiftUI production,
data lifecycle, security, privacy, accessibility/global readiness, observability, modern testing,
performance/resilience, or supply-chain/legal concerns. The enterprise router selects among the ten
focused chapters; their files remain the single source of detailed standards.

`brain-flow` uses provider-native planning, delegation, and semantic workstreams to execute one
approved plan, then runs one joined final AI consistency review over the complete result. Claude Code
selects its packaged specialists with exact `ifl-ios-standards:ios-*` IDs; Codex maps the same bounded
responsibilities to provider-native generic subagents. Eligible full-auto delivery ends at engineering
completion and release readiness; it does not imply push, tag, publication, installation, or rollout.

## How references resolve

Every reference inside agents/skills points at bundled content via `${CLAUDE_PLUGIN_ROOT}`. Claude
Code expands it; Codex resolves it relative to the installed skill/plugin root. The standards remain
self-contained. Codex Brain Flow uses provider-native generic subagents with exact bounded
assignments and inline recovery; it does not require project custom-agent profiles.

**Per-project values are NOT bundled** — scheme, simulator, module roots, build/test commands,
base branch, git remote, naming prefix, and ADR/decisions location live in the **consuming repo's
`CLAUDE.md`**. Run `ifl-init` to seed the twin bindings, or copy a starter from
`standards/templates/portable-claude/`. The multi-agent pipeline's
work-item workspace (in-repo under `docs/02-working-docs/work-items/` per the docs-organization process
standard) is **optional**, used only by the orchestrator pipeline.

## Install the published release

Public installation is pinned to the immutable published `v1.0.0` tag:

**Claude Code**

```bash
claude plugin marketplace add congncif/ifl-ios-standards#v1.0.0
claude plugin install ifl-ios-standards@ifl-ios-standards
```

**Codex**

```bash
codex plugin marketplace add congncif/ifl-ios-standards --ref v1.0.0
codex plugin add ifl-ios-standards@ifl-ios-standards
```

The local-checkout scripts described in [INSTALL.md](INSTALL.md) are qualification/development paths,
not public candidate installation guidance. Use them only under explicit installation authority that names
the exact candidate checkout/commit and intended scope.

## Versioning

Both provider manifests mirror the upstream pack `VERSION`. The published release and public pin are
`1.0.0` / `v1.0.0`. Future publication and installation remain separately authorized operations.

## License

Distributed under the packaged [MIT License](LICENSE).
