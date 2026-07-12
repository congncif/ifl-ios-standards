# Deploy ifl-ios-standards to GitHub

> CI integration remains owned by DevOps and is outside this repository's plugin workflow. For
> `1.0.0-rc.1`, the Human Legal/Release Owner has separately authorized MIT public distribution,
> the Git push/tag, local plugin update, and E2E requested for this release.

> **License decision.** The marketplace repository and packaged plugin are distributed under the
> [MIT License](LICENSE). Both provider manifests declare `MIT`, and the plugin archive carries its
> own `ifl-ios-standards/LICENSE` copy.

The marketplace currently lives on a removable drive. Pushing it to GitHub makes it installable
from anywhere (teammates and fresh machines) with no drive and no clone.

## Repo shape

Both runtimes read a marketplace manifest at the **repo root**: Claude Code from
`.claude-plugin/marketplace.json`, Codex from `.codex-plugin/marketplace.json`. This `marketplace/`
directory has both:

```
<repo root>/
├── .claude-plugin/marketplace.json     # Claude — plugins[].source = "./ifl-ios-standards"
├── .codex-plugin/marketplace.json      # Codex  — plugins[].source = git-subdir → ./ifl-ios-standards
├── ifl-ios-standards/                  # the plugin
│   ├── .claude-plugin/plugin.json      #   Claude plugin manifest
│   ├── .codex-plugin/plugin.json       #   Codex plugin manifest
│   ├── agents/ skills/ standards/ bin/ #   shared content (both runtimes)
│   └── scripts/{install-claude,install-codex}.sh
├── install.sh                          # standalone Claude installer (add-by-repo-name + install)
├── DEPLOY.md                           # this file
└── README.md / INSTALL.md
```

So the repo root = the **contents of this `marketplace/` dir** (a dedicated marketplace repo,
separate from the ifl-ios-pack source). One `git push` updates both runtimes.

## One-time public push

```bash
cd /Volumes/KingstonXS1000/WORKSPACE/ABC/ifl-ios-pack/marketplace

git init
git add .
git commit -m "ifl-ios-standards marketplace v1.0.0-rc.1"

# create the public repo under your account and push (gh is logged in as congncif)
gh repo create congncif/ifl-ios-standards --public --source=. --remote=origin --push
```

Tag the version so installs can pin it:

```bash
git tag v1.0.0-rc.1
git push origin v1.0.0-rc.1
```

> If `marketplace/` is also tracked by the parent `ifl-ios-pack` repo, keep it ignored there
> (`echo 'marketplace/' >> ../.gitignore`) so the two repos don't nest — a dedicated marketplace
> repo is the clean model.

## Install from GitHub (teammates / fresh machine)

Works exactly like any public plugin — **no clone, no drive, no jq**. Two CLI commands by repo name.

**Claude Code:**
```bash
claude plugin marketplace add  congncif/ifl-ios-standards          # default branch
claude plugin install          ifl-ios-standards@ifl-ios-standards
# (pin the release candidate: add  congncif/ifl-ios-standards#v1.0.0-rc.1  instead)
```

**Codex:**
```bash
codex plugin marketplace add   congncif/ifl-ios-standards          # --ref v1.0.0-rc.1 to pin
codex plugin add               ifl-ios-standards@ifl-ios-standards
```

`marketplace add` records the marketplace and `install`/`add` enables the plugin — the CLI persists
both (Claude → settings, Codex → `~/.codex/config.toml`), so nothing manual. Then `/reload-plugins`
(Claude) or a new thread (Codex).

The repo also ships `install.sh` (the same two commands, with `--ref` / `--scope` flags) for a
one-liner — it does **not** need the repo cloned:

```bash
curl -fsSL https://raw.githubusercontent.com/congncif/ifl-ios-standards/main/install.sh | bash
# or with flags:
curl -fsSL https://raw.githubusercontent.com/congncif/ifl-ios-standards/main/install.sh | bash -s -- --ref=v1.0.0-rc.1 --scope=project
```

Or settings-only auto-enable (`~/.claude/settings.json` for global):

```json
{
  "extraKnownMarketplaces": {
    "ifl-ios-standards": { "source": { "source": "github", "repo": "congncif/ifl-ios-standards" }, "autoUpdate": true }
  },
  "enabledPlugins": { "ifl-ios-standards@ifl-ios-standards": true }
}
```

## Two transports, one marketplace name

The marketplace declared name is `ifl-ios-standards` whether the source is the drive
(`directory`) or GitHub (`github`). **Register only one transport at a time** under that name. If a
drive install already registered it, remove it before adding the GitHub one:

```bash
claude plugin marketplace remove ifl-ios-standards
claude plugin marketplace add    congncif/ifl-ios-standards
```

To go back to the drive, re-run `ifl-ios-standards/scripts/install-claude.sh`.

## DevOps publication handoff

1. Confirm the repository and packaged plugin LICENSE files are identical MIT text and both provider
   manifests declare `MIT`.
2. Confirm `ifl-ios-standards/VERSION`, both provider manifest versions, and the Codex marketplace
   source `ref` match the release tag.
3. DevOps runs organization-owned CI and publication checks when that boundary is invoked.
4. Under explicit release authority, perform `git commit` + `git push`; then
   `git tag vX.Y.Z && git push origin vX.Y.Z`.
5. Installs with `autoUpdate: true` pick up the default branch; pinned installs move when you
   re-add with the new `#vX.Y.Z`, or run `claude plugin marketplace update ifl-ios-standards`.

## Private-repo note

If you make the repo private instead, `claude plugin marketplace add congncif/ifl-ios-standards`
still works as long as the machine has GitHub auth (gh login or SSH key). The `curl | bash`
one-liner needs a token for a private repo, so for private use the two raw `claude plugin` commands
above (they use the machine's existing git auth) rather than the curl pipe.
