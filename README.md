# ifl-ios-standards — Claude Code + Codex marketplace

A **plugin marketplace** distributing reusable **iOS engineering standards** — specialist
agents, pattern-neutral brain workflows, Boardy/VIP task skills, the full architecture references,
and Bazel module/board scaffolders. **One repo, both runtimes**: it ships
`.claude-plugin/marketplace.json` (Claude Code) and `.codex-plugin/marketplace.json` (Codex) at its
root, like a dual-runtime plugin.

## Install — Claude Code

Like any public plugin — two CLI commands, no clone, no drive:

```bash
claude plugin marketplace add  congncif/ifl-ios-standards
claude plugin install          ifl-ios-standards@ifl-ios-standards
```

Pin a version: `claude plugin marketplace add congncif/ifl-ios-standards#v0.18.1`.
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

Update from a specific branch, tag, or ref:

```bash
./install.sh --ref=main --scope=user
claude plugin marketplace update ifl-ios-standards
claude plugin update -s user ifl-ios-standards@ifl-ios-standards

# or pin a release tag
./install.sh --ref=v0.18.1 --scope=user
claude plugin marketplace update ifl-ios-standards
claude plugin update -s user ifl-ios-standards@ifl-ios-standards
```

Verify:

```bash
claude plugin list | grep -A4 -B1 'ifl-ios-standards@ifl-ios-standards'
```

Run `/reload-plugins` or restart Claude Code after updating.

One-liner (no clone):

```bash
curl -fsSL https://raw.githubusercontent.com/congncif/ifl-ios-standards/main/install.sh | bash
# flags: | bash -s -- --ref=v0.18.1 --scope=project
```

## Install — Codex

```bash
codex plugin marketplace add  congncif/ifl-ios-standards          # --ref v0.18.1 to pin
codex plugin add              ifl-ios-standards@ifl-ios-standards
```

One-liner:

```bash
curl -fsSL https://raw.githubusercontent.com/congncif/ifl-ios-standards/main/ifl-ios-standards/scripts/install-codex.sh | bash
```

> Codex doesn't expand `${CLAUDE_PLUGIN_ROOT}` — reference paths shown that way in skills/agents
> resolve **relative to the plugin's root directory** under Codex. Skills + agents are
> auto-discovered the same way as in Claude Code.

## What you get

| Component | Count | What |
|-----------|-------|------|
| Agents | 9 | `ios-orchestrator` (tech lead), `ios-planner`, `ios-researcher`, `ios-architect`, `ios-coder`, `ios-tester`, `ios-reviewer`, `ios-review-triage`, `ios-doc-scribe` |
| Skills | 20 | **Brain stages** (pattern-neutral): `brain-design`, `brain-architect`, `brain-plan`, `brain-execute`, `brain-testing`, `brain-review`, `brain-flow` (end-to-end automation) · **Boardy/VIP tasks**: router `boardy-vip` (for Boardy/VIP routing) + `boardy-new-module`, `boardy-new-board`, `boardy-io-interface`, `boardy-communication`, `boardy-service-layer`, `boardy-plugin-composition`, `boardy-testing`, `boardy-review`, `boardy-refactor`, `boardy-troubleshoot`, `boardy-adopt` · `init` |
| Reference | — | Full rulebook, 43 specs + process standards, lint scripts, `portable-claude` templates (bundled under `standards/`) |
| Scaffolders | 3 | `ifl-init` (seed CLAUDE.md/AGENTS.md), `ifl-new-module`, `ifl-new-board` — Bazel-aware; Claude exposes plugin `bin/` directly, while Codex uses `scripts/install-codex.sh` to create shims in `~/.local/bin` |

## New project? Init the bindings first

A project adopts the standard by carrying a `CLAUDE.md` + `AGENTS.md` with its own bindings. Seed them:

```bash
ifl-init --root=.            # detects git/manager/module-root, writes CLAUDE.md + AGENTS.md
# or, agent-driven (also fills scheme/build/test by introspection):
/ifl-ios-standards:init
```

Then fill any remaining `{Placeholders}` (scheme, simulator, build/test commands).

## Use it

After install + init, describe the iOS task. Use `brain-*` skills for pattern-neutral workflow,
or call a Boardy/VIP skill directly when the project uses Boardy/VIP:

```text
/ifl-ios-standards:boardy-vip          # router — read first, routes to the right skill/spec
/ifl-ios-standards:init                # seed CLAUDE.md + AGENTS.md for a new project
/ifl-ios-standards:brain-flow          # automate the whole workflow: analyze → … → done
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
- [`ifl-ios-standards/README.md`](ifl-ios-standards/README.md) — plugin internals + reference layout.
- [`ifl-ios-standards/INSTALL.md`](ifl-ios-standards/INSTALL.md) — install scopes + drive-source / manual options.

## Versioning

Plugin `version` (in `ifl-ios-standards/.claude-plugin/plugin.json`) follows the upstream pack
`VERSION` (currently `0.18.1`). Bump on content changes; tag `vX.Y.Z` so installs can pin.
