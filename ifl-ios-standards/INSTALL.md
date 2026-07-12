# Install ifl-ios-standards

## Quick install (recommended)

From this plugin dir (drive must be mounted):

```bash
scripts/install-claude.sh
```

Defaults to **global (user) scope** — the plugin is enabled in every project. The script:

1. `claude plugin validate` the plugin + the marketplace (offline check).
2. `claude plugin marketplace add --scope user <marketplace root>`.
3. `claude plugin install --scope user ifl-ios-standards@ifl-ios-standards`.
4. Merges the auto-enable block into `~/.claude/settings.json` (via `jq`; prints it for manual
   paste if `jq` is missing).

## Scopes

| Command | Effect | Settings file written |
|---------|--------|-----------------------|
| `scripts/install-claude.sh` | global — all projects | `~/.claude/settings.json` |
| `scripts/install-claude.sh --scope=project --project=/path/to/repo` | one repo | `<repo>/.claude/settings.local.json` |
| `scripts/install-claude.sh --scope=local` | this checkout only | none (no settings file written) |

## Manual install

```bash
claude plugin marketplace add  /Volumes/KingstonXS1000/WORKSPACE/ABC/ifl-ios-pack/marketplace
claude plugin install          ifl-ios-standards@ifl-ios-standards
```

Or pre-seed settings (`~/.claude/settings.json` for global, repo `.claude/settings.local.json` for project):

```json
{
  "extraKnownMarketplaces": {
    "ifl-ios-standards": {
      "source": { "source": "directory", "path": "/Volumes/KingstonXS1000/WORKSPACE/ABC/ifl-ios-pack/marketplace" }
    }
  },
  "enabledPlugins": { "ifl-ios-standards@ifl-ios-standards": true }
}
```

## After install

- Restart Claude Code, or run `/reload-plugins`, if discovery doesn't refresh.
- Confirm discovery: `claude plugin list` shows `ifl-ios-standards@ifl-ios-standards` enabled;
  `/agents` lists the 9 `ios-*` agents; `/ifl-ios-standards:boardy-vip` resolves.
- Wire the consuming repo: copy a starter from `standards/templates/portable-claude/` into the
  repo's `CLAUDE.md` and fill in scheme / module roots / build commands / base branch / remote.

## Removable-drive note

The plugin is **copied into `~/.claude/plugins/cache/`** at install time, so it keeps working after
the pack drive (`/Volumes/KingstonXS1000`) is unmounted. The drive only needs to be remounted to
**re-install or update** (the `extraKnownMarketplaces.source.path` points at the drive). To make it
fully drive-independent, copy the `marketplace/` dir to a stable location and point the marketplace
source there instead.

## Codex

Same repo serves Codex via its `.codex-plugin/` manifests:

```bash
codex plugin marketplace add  congncif/ifl-ios-standards          # --ref v1.0.0-rc.1 to pin
codex plugin add              ifl-ios-standards@ifl-ios-standards
```

Or the bundled installer: `scripts/install-codex.sh` (`--ref` optional). `codex plugin add`
records the install in `~/.codex/config.toml`; the installer also creates `~/.local/bin` shims for
`ifl-init`, `ifl-new-module`, and `ifl-new-board` because Codex does not currently guarantee plugin
`bin/` directories are exported to shell `PATH`. The shims resolve the most recently installed
available cache entry at invocation time. Add `~/.local/bin` to `PATH` if the shell does not already
include it. Start a new Codex thread to pick up the skills/agents.
Codex resolves `${CLAUDE_PLUGIN_ROOT}/standards/…` paths relative to the plugin root (no var expansion).

## Prerequisites

- `claude` CLI (Claude Code) or `codex` CLI (Codex) on PATH.
- `jq` (optional) for the Claude installer's automatic settings merge; without it it prints the block to paste.
- For the scaffolders: a consuming iOS source tree; the generators are thin and build-system-neutral.
