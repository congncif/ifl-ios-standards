# Deploy ifl-ios-standards to GitHub

> **Current status (2026-07-14):** this branch contains the unpublished `1.0.0-rc.2` working
> candidate. The latest published release is `v1.0.0-rc.1`, and the public Codex marketplace source
> remains pinned to that tag. No RC2 push, tag, marketplace publication, install, or rollout is
> authorized by candidate preparation.

> **License:** the marketplace repository and packaged plugin remain distributed under the
> [MIT License](LICENSE). Both provider manifests declare `MIT`, and the plugin payload includes
> `ifl-ios-standards/LICENSE`.

CI and release automation belong to the consuming organization/DevOps boundary. Treat each external
effect below as a separate operation with separately recorded authority.

## Repository and payload shape

Both runtimes read a marketplace manifest at the repository root: Claude Code uses
`.claude-plugin/marketplace.json`; Codex uses `.codex-plugin/marketplace.json`. The installable payload
is the `ifl-ios-standards/` subtree. Repository-root working docs, roadmap material, and the inactive
post-1.0 backlog are not part of that plugin payload.

```text
<repo root>/
├── .claude-plugin/marketplace.json
├── .codex-plugin/marketplace.json
├── ifl-ios-standards/
│   ├── .claude-plugin/plugin.json
│   ├── .codex-plugin/plugin.json
│   ├── agents/ skills/ standards/ bin/
│   └── scripts/{install-claude,install-codex}.sh
├── DEPLOY.md
├── ROADMAP.md
├── README.md
└── install.sh
```

## Authority matrix

| Operation | Required authority | Never implied by |
|-----------|--------------------|------------------|
| Stage and local commit | Scoped repository/worktree/branch and path authority | Plan approval, auto mode, tests, review |
| Create or switch a branch | Branch authority | Local commit authority |
| Create a remote repository | Repository-administration authority | Initial local setup |
| Push a non-distribution candidate branch | Remote Git authority for the exact branch/commit | Local commit or remote creation |
| Push a ref consumed by an unpinned public channel, including the default branch | Remote Git **and** marketplace/release authority | Ordinary branch-push authority |
| Create a tag | Tag authority for the exact version/commit | Version metadata |
| Push a tag | Remote tag authority | Local tag creation |
| Change marketplace source/ref or publish a release | Marketplace/release authority | Tag creation or push |
| Install/update a local or project plugin | Machine/project installation authority | Publication |
| Production rollout | Release/sign-off authority | Any prior operation |

Commands in this document are handoff examples, not standing authorization.

## Initial publication of a new repository

Use this path only when the remote repository does not exist. Repository creation, first push, tag,
publication, and installation are distinct decisions.

1. Under local repository authority, initialize Git and stage an explicit allowlist. Never stage the
   current directory, all changes, a wildcard, an implicit path, or a directory whose descendants
   have not been individually approved.

   ```bash
   git init
   git add -- \
     .claude-plugin/marketplace.json \
     .codex-plugin/marketplace.json \
     DEPLOY.md \
     LICENSE \
     README.md \
     ROADMAP.md \
     install.sh \
     ifl-ios-standards/.claude-plugin/plugin.json \
     ifl-ios-standards/.codex-plugin/plugin.json \
     ifl-ios-standards/CHANGELOG.md \
     ifl-ios-standards/INSTALL.md \
     ifl-ios-standards/LICENSE \
     ifl-ios-standards/README.md \
     ifl-ios-standards/RELEASE.md \
     ifl-ios-standards/VERSION

   # Prepare this temporary allowlist with one reviewed, exact repository-relative file path per
   # line for every approved payload file under agents/, bin/, scripts/, skills/, and standards/.
   # Do not put directory paths or glob patterns in it.
   git add --pathspec-from-file=/tmp/ifl-ios-standards-initial-payload-paths.txt
   git diff --cached --name-only
   git commit -m "publish ifl-ios-standards <authorized-version>"
   ```

   Add repository-root backlog or governance paths only when the release owner explicitly includes
   them; their presence at repository root never places them in the plugin payload.

2. Under repository-administration authority, create the remote without bundling a push:

   ```bash
   gh repo create congncif/ifl-ios-standards --public --source=. --remote=origin
   ```

3. Under separate branch-push authority, push only the authorized branch. An unpublished candidate
   must use a branch that is neither the public default nor referenced by public install guidance.
   Because Claude resolves the plugin subtree from the fetched repository ref, pushing the public
   default branch can itself distribute new payload content and therefore also requires
   marketplace/release authority.

   ```bash
   git push -u origin <authorized-branch>
   ```

4. Continue to the tag/publication sections only after their own approvals.

## Update an existing repository

Use this path when the remote already exists. Do not re-run `git init` or repository creation.

1. Inspect the current branch, remote, and working tree. Switching or creating a branch requires its
   own authority.
2. Apply the approved candidate changes.
3. Stage only the exact paths belonging to the semantic update. For the complete RC2
   governance/metadata semantic task described by this repository, the explicit allowlist is:

   ```bash
   git add -- \
     DEPLOY.md \
     README.md \
     ROADMAP.md \
     docs/02-working-docs/work-items/IIS-0003-standards-1.0-ga/plan.md \
     docs/02-working-docs/work-items/IIS-0003-standards-1.0-ga/requirements.md \
     ifl-ios-standards/.claude-plugin/plugin.json \
     ifl-ios-standards/.codex-plugin/plugin.json \
     ifl-ios-standards/CHANGELOG.md \
     ifl-ios-standards/INSTALL.md \
     ifl-ios-standards/README.md \
     ifl-ios-standards/RELEASE.md \
     ifl-ios-standards/VERSION \
     ifl-ios-standards/scripts/install-codex.sh \
     ifl-ios-standards/standards/COMPATIBILITY.md \
     ifl-ios-standards/standards/GOVERNANCE.md \
     ifl-ios-standards/standards/brain/CHANGELOG.md \
     ifl-ios-standards/standards/templates/portable-claude/AGENTS.md \
     ifl-ios-standards/standards/templates/portable-claude/CHANGELOG.md \
     ifl-ios-standards/standards/templates/portable-claude/CLAUDE.md \
     ifl-ios-standards/standards/templates/portable-claude/README.md \
     ifl-ios-standards/standards/templates/portable-claude/SETUP.md \
     ifl-ios-standards/standards/templates/portable-claude/VERSION \
     ifl-ios-standards/standards/templates/portable-claude/examples/PROJECT_CONFIG.example.md \
     ifl-ios-standards/standards/templates/portable-claude/examples/PROJECT_STRUCTURE.example.md \
     ifl-ios-standards/standards/templates/portable-claude/examples/QUICK_REF.example.md \
     ifl-ios-standards/standards/templates/portable-claude/examples/README.md \
     install.sh
   git diff --cached --name-only
   git commit -m "prepare ifl-ios-standards 1.0.0-rc.2 candidate"
   ```

   This allowlist is complete only for that named semantic task. For any later task, derive a new list
   from the approved scope and inspected diff, enumerate every reviewed repository-relative file path,
   and do not reuse this list as a generic release path set.

4. Stop at the local commit unless branch-push authority is separately granted. For an unpublished
   candidate, any authorized push must target a non-distribution candidate branch. Pushing a ref used
   by an unpinned public channel—especially the default branch—also requires marketplace/release
   authority. A local RC2 candidate commit does not authorize publication.

## Tag and marketplace publication

The current working candidate must not use these commands because no `v1.0.0-rc.2` tag or release
authority exists. Once a specific version and candidate commit are approved:

1. Confirm `ifl-ios-standards/VERSION` and both provider manifest versions equal the authorized tag.
2. Confirm the repository and plugin licenses are the approved MIT text.
3. Run organization-owned qualification and collect the named release sign-offs.
4. Under tag-creation authority:

   ```bash
   git tag <authorized-tag> <authorized-commit>
   ```

5. Under separate remote-tag authority:

   ```bash
   git push origin <authorized-tag>
   ```

6. Only under marketplace/release authority, update public marketplace metadata to the published tag
   and publish the release. Until that step, `.codex-plugin/marketplace.json` remains at
   `v1.0.0-rc.1`.

## Install a published release

Installation is a consumer or machine operation, not part of candidate preparation or publication.
The latest published pin remains RC1:

**Claude Code**

```bash
claude plugin marketplace add congncif/ifl-ios-standards#v1.0.0-rc.1
claude plugin install ifl-ios-standards@ifl-ios-standards
```

**Codex**

```bash
codex plugin marketplace add congncif/ifl-ios-standards --ref v1.0.0-rc.1
codex plugin add ifl-ios-standards@ifl-ios-standards
```

Register only one marketplace transport at a time under the `ifl-ios-standards` name. Updating or
removing an existing local registration also requires the relevant machine/project authority.

## DevOps release handoff

Before declaring a release published, record:

1. Candidate commit and exact included paths.
2. Qualification results and named engineering, security/privacy, legal, and release sign-offs.
3. Separate dispositions for local commit, branch push, tag creation, tag push, marketplace
   publication, installation/update, and rollout.
4. The published marketplace ref and rollback/de-promotion target.
5. Confirmation that public install guidance names only a tag that actually exists.

See [ROADMAP.md](ROADMAP.md) for deferred, evidence-triggered 1.1 work. Roadmap items are not release
requirements unless a separately approved work item promotes them.
