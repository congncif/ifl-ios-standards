# Deploy ifl-ios-standards to GitHub

The marketplace currently lives on a removable drive. Pushing it to GitHub makes it installable
from anywhere (teammates, CI, fresh machines) with no drive and no clone.

## Repo shape

GitHub marketplace add requires `.claude-plugin/marketplace.json` at the **repo root**. This
`marketplace/` directory already has that shape:

```
<repo root>/
├── .claude-plugin/marketplace.json     # plugins[].source = "./ifl-ios-standards"
├── ifl-ios-standards/                  # the plugin (manifest, agents, skills, standards, bin, scripts)
├── install-from-github.sh              # teammate one-command installer (GitHub transport)
├── DEPLOY.md                           # this file
└── README.md / INSTALL.md
```

So the repo root = the **contents of this `marketplace/` dir** (a dedicated marketplace repo,
separate from the ifl-ios-pack source).

## One-time push (run from the drive)

```bash
cd /Volumes/KingstonXS1000/WORKSPACE/ABC/ifl-ios-pack/marketplace

git init
git add .
git commit -m "ifl-ios-standards marketplace v0.14.0"

# create the public repo under your account and push (gh is logged in as congncif)
gh repo create congncif/ifl-ios-standards --public --source=. --remote=origin --push
```

Tag the version so installs can pin it:

```bash
git tag v0.14.0
git push origin v0.14.0
```

> If `marketplace/` is also tracked by the parent `ifl-ios-pack` repo, keep it ignored there
> (`echo 'marketplace/' >> ../.gitignore`) so the two repos don't nest — a dedicated marketplace
> repo is the clean model.

## Install from GitHub (teammates / CI / fresh machine)

Once pushed, anyone runs the bundled installer (no drive needed):

```bash
# clone-free: fetch the script straight from the repo, then run it
curl -fsSL https://raw.githubusercontent.com/congncif/ifl-ios-standards/main/install-from-github.sh | bash

# or, having cloned the repo:
./install-from-github.sh                       # global (user scope)
./install-from-github.sh --ref=v0.14.0         # pin a tag
./install-from-github.sh --scope=project --project=/path/to/repo
```

Or the raw Claude CLI:

```bash
claude plugin marketplace add  congncif/ifl-ios-standards          # default branch
claude plugin marketplace add  congncif/ifl-ios-standards#v0.14.0  # pinned tag
claude plugin install          ifl-ios-standards@ifl-ios-standards-local
```

Or settings-only auto-enable (`~/.claude/settings.json` for global):

```json
{
  "extraKnownMarketplaces": {
    "ifl-ios-standards-local": { "source": { "source": "github", "repo": "congncif/ifl-ios-standards" }, "autoUpdate": true }
  },
  "enabledPlugins": { "ifl-ios-standards@ifl-ios-standards-local": true }
}
```

## Two transports, one marketplace name

The marketplace declared name is `ifl-ios-standards-local` whether the source is the drive
(`directory`) or GitHub (`github`). **Register only one transport at a time** under that name —
`install-from-github.sh` removes any existing same-name marketplace before adding the GitHub one,
so switching from drive → GitHub is safe. To go back to the drive, re-run
`ifl-ios-standards/scripts/install-claude.sh`.

## Updating

1. Edit content under `ifl-ios-standards/`.
2. Bump `version` in `ifl-ios-standards/.claude-plugin/plugin.json` (SemVer).
3. `git commit` + `git push`; `git tag vX.Y.Z && git push origin vX.Y.Z`.
4. Installs with `autoUpdate: true` pick up the default branch; pinned installs move when you
   re-add with the new `#vX.Y.Z`, or run `claude plugin marketplace update ifl-ios-standards-local`.

## Private-repo note

If you make the repo private instead, `claude plugin marketplace add` still works as long as the
machine has GitHub auth (gh login or SSH key). `curl` of the raw installer needs a token, so
teammates clone via `gh repo clone congncif/ifl-ios-standards` then run `./install-from-github.sh`.
