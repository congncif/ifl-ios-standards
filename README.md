# ifl-ios-standards — Claude Code + Codex marketplace

A **plugin marketplace** distributing reusable **iOS engineering standards** — 9 specialist
agents, 21 skills including `enterprise-ios`, provider-native Brain Flow, Boardy/VIP task skills,
ten focused enterprise chapters, and thin build-system-neutral module/board source scaffolders.
**One repo, both runtimes**: it ships
`.claude-plugin/marketplace.json` (Claude Code) and `.codex-plugin/marketplace.json` (Codex) at its
root, like a dual-runtime plugin.

> **Release status (2026-07-14):** this branch describes the unpublished `1.0.0-rc.4` working
> candidate. The latest published/tag-installable release is `v1.0.0-rc.1`; public install pins and
> the Codex marketplace ref remain on RC1 until a separately authorized candidate publication.

## Install — Claude Code

Like any public plugin — two CLI commands, no clone, no drive:

```bash
claude plugin marketplace add  congncif/ifl-ios-standards#v1.0.0-rc.1
claude plugin install          ifl-ios-standards@ifl-ios-standards
```

This explicitly pins the latest published release candidate.
Then `/reload-plugins` (or restart Claude Code).

### Update installed plugin

Update the configured marketplace, then update the installed plugin for the desired scope:

```bash
# user scope
claude plugin marketplace update ifl-ios-standards
claude plugin update -s user ifl-ios-standards@ifl-ios-standards

# project scope
claude plugin marketplace update ifl-ios-standards
claude plugin update -s project ifl-ios-standards@ifl-ios-standards
```

Update from the published RC1 tag:

```bash
./install.sh --ref=v1.0.0-rc.1 --scope=user
claude plugin marketplace update ifl-ios-standards
claude plugin update -s user ifl-ios-standards@ifl-ios-standards
```

A branch or commit ref is a development/qualification input, not a published release. Use one only
under an explicit qualification or installation instruction that names the exact ref.

Verify:

```bash
claude plugin list | grep -A4 -B1 'ifl-ios-standards@ifl-ios-standards'
```

Run `/reload-plugins` or restart Claude Code after updating.

One-liner (no clone):

```bash
curl -fsSL https://raw.githubusercontent.com/congncif/ifl-ios-standards/v1.0.0-rc.1/install.sh | \
  bash -s -- --ref=v1.0.0-rc.1 --scope=user
```

## Install — Codex

```bash
codex plugin marketplace add  congncif/ifl-ios-standards --ref v1.0.0-rc.1
codex plugin add              ifl-ios-standards@ifl-ios-standards
```

One-liner:

```bash
curl -fsSL https://raw.githubusercontent.com/congncif/ifl-ios-standards/v1.0.0-rc.1/ifl-ios-standards/scripts/install-codex.sh | \
  bash -s -- --ref=v1.0.0-rc.1
```

> Codex doesn't expand `${CLAUDE_PLUGIN_ROOT}` — reference paths shown that way in skills/agents
> resolve **relative to the plugin's root directory** under Codex. Skills + agents are
> auto-discovered the same way as in Claude Code.

## What you get

| Component | Count | What |
|-----------|-------|------|
| Agents | 9 | `ios-orchestrator` (tech lead), `ios-planner`, `ios-researcher`, `ios-architect`, `ios-coder`, `ios-tester`, `ios-reviewer`, `ios-review-triage`, `ios-doc-scribe` |
| Skills | 21 | **Brain stages** (pattern-neutral, provider-native): `brain-design`, `brain-architect`, `brain-plan`, `brain-execute`, `brain-testing`, `brain-review`, `brain-flow` (end-to-end automation) · **Boardy/VIP tasks**: router `boardy-vip` + `boardy-new-module`, `boardy-new-board`, `boardy-io-interface`, `boardy-communication`, `boardy-service-layer`, `boardy-plugin-composition`, `boardy-testing`, `boardy-review`, `boardy-refactor`, `boardy-troubleshoot`, `boardy-adopt` · **Enterprise iOS**: router `enterprise-ios` · `init` |
| Reference | — | Full rulebook, specs + process standards, ten focused enterprise chapters, and `portable-claude` templates (bundled under `standards/`) |
| Scaffolders | 3 | `ifl-init` (seed CLAUDE.md/AGENTS.md), `ifl-new-module`, `ifl-new-board` — thin build-system-neutral source scaffolders in plugin `bin/`; command-name invocation requires the runtime to export that directory or an installed shim directory to be on shell `PATH` |

## New project? Init the bindings first

A project adopts the standard by carrying a `CLAUDE.md` + `AGENTS.md` with its own bindings. Seed them:

```bash
ifl-init --root=.            # fills only unambiguous observed values; leaves governed values unresolved
# or, agent-driven (resolves remaining bindings from repository evidence or asks):
/ifl-ios-standards:init
```

Then resolve every remaining project binding from repository evidence or its accountable owner. Never
invent a remote, base branch, module root, destination, or build/test command.

## Use it

After install + init, describe the iOS task. Use `brain-*` skills for pattern-neutral workflow,
call a Boardy/VIP skill directly when the project uses Boardy/VIP, or use `enterprise-ios` to route
enterprise concerns to the relevant chapter:

```text
/ifl-ios-standards:boardy-vip          # router — read first, routes to the right skill/spec
/ifl-ios-standards:init                # seed CLAUDE.md + AGENTS.md for a new project
/ifl-ios-standards:brain-flow          # automate the whole workflow: analyze → … → done
/ifl-ios-standards:enterprise-ios      # route to one or more enterprise chapters
/ifl-ios-standards:boardy-new-module
/ifl-ios-standards:boardy-new-board
/ifl-ios-standards:boardy-review
# … per-stage: :brain-design :brain-architect :brain-plan :brain-execute :brain-testing :brain-review
```

For multi-step delivery, delegate to the bundled agents (start with `ios-orchestrator`); they
appear in `/agents`.

## Per-project setup

This pack ships the **generic** standard. Per-project values — scheme, simulator, module roots,
build/test commands, base branch, git remote, naming prefix, ADR/decisions location — belong in the
consuming repo's `CLAUDE.md`. A copyable starter ships at
[`ifl-ios-standards/standards/templates/portable-claude/`](ifl-ios-standards/standards/templates/portable-claude/).
The multi-agent pipeline's handoff workspace (in-repo under `docs/02-working-docs/handoffs/` per the
docs-organization process standard) is optional.

## Docs

- [`DEPLOY.md`](DEPLOY.md) — publishing + updating this marketplace on GitHub.
- [`ROADMAP.md`](ROADMAP.md) — evidence-triggered 1.1 lifecycle topics and the post-1.0 kernel boundary.
- [`ifl-ios-standards/README.md`](ifl-ios-standards/README.md) — plugin internals + reference layout.
- [`ifl-ios-standards/INSTALL.md`](ifl-ios-standards/INSTALL.md) — install scopes + drive-source / manual options.

## Versioning

Plugin `version` in both provider manifests follows the upstream pack `VERSION`. Local candidate
metadata is `1.0.0-rc.4`, but it is unpublished; the latest published tag and public install pin are
still `v1.0.0-rc.1`. A version string never grants push, tag, publication, or installation authority.

## License

Distributed under the [MIT License](LICENSE).
