<!-- template-version: 2.5.0 -->

# PROJECT_CONFIG.example.md — placeholder-only shape reference

> **Do not copy project values from an example.** This file contains placeholders only. Generate the
> real `PROJECT_CONFIG.md` from explicit user answers and read-only repository evidence. If a required
> value cannot be resolved, write `TBD` and surface it; never substitute a fictional app, module,
> scheme, destination, path, remote, command, authority, or policy value.

---

# PROJECT_CONFIG — Project Configuration Contract

> **Purpose**: one editable contract for consuming-repository values. Generic standards, skills, and
> agents read these bindings instead of hard-coding project details.
>
> **Boundary**: current schemes, modules, purposes, and topology live in
> `<BindingsRoot>/PROJECT_STRUCTURE.md`. Active Canon Rules/Profiles and accepted ADRs are the
> normative reusable authority; plugin skills/specs/process docs are derived operating guidance.

---

## 1. Identity Configuration

| Key | Value |
|-----|-------|
| `{ProjectName}` | `{ProjectName}` |
| `{WorkspaceOrProject}` | `{WorkspaceOrProject}` |
| `{MainScheme}` | `{MainScheme}` |
| `{ModulePrefix}` | `{ModulePrefix}` |
| `{BaseBranch}` | `{BaseBranch}` |
| `{GitRemote}` | `{GitRemote}` |
| `{GitRemoteURL}` | `{GitRemoteURL}` |
| `{Simulator}` | `{Simulator}` |
| `{Destination}` | `{Destination}` |

Every value above must resolve from the consuming repository or user. An empty optional prefix is a
real resolved value; do not invent a prefix.

---

## 2. Project-Wide Path Configuration

| Concern | Value |
|---------|-------|
| Module root | {ModuleRoot} |
| Bindings root | `{BindingsRoot}` |
| Project structure inventory | `{ProjectStructure}` |
| Working-docs root | `{WorkingDocsRoot}` |
| Living-docs root | `{LivingDocsRoot}` |
| Archive root | `{ArchiveRoot}` |

The real **Module root** value must be one repository-relative path token with no explanatory prose.
`ifl-new-module` and `ifl-new-board` resolve it from root `CLAUDE.md`, then `AGENTS.md`, and fail
instead of guessing. An explicit `--module-root` may override the binding.

---

## 3. Tooling and Source-Boundary Configuration

| Concern | Value |
|---------|-------|
| Build/package system | `{BuildSystem}` |
| Build/package integration | `{BuildIntegration}` |
| App composition host | `{CompositionHost}` |
| Public contract target pattern | `{InterfaceTargetPattern}` |
| Implementation target pattern | `{ImplementationTargetPattern}` |
| Test target pattern | `{TestTargetPattern}` |
| Public contract source glob | `{InterfaceSourceGlob}` |
| Implementation source glob | `{ImplementationSourceGlob}` |
| Test source glob | `{TestSourceGlob}` |
| Localization tool/command | `{LocalizationCommand}` |

For Boardy+VIP, preserve public IO and internal implementation source boundaries. The module/board
scaffolders emit additive source skeletons only: they do not emit or edit build/package files,
dependencies, target definitions, platform values, resources, commands, or CI configuration.

---

## 4. Build, Test, Debug, and CI Configuration

Record the consuming repository's canonical commands verbatim:

```bash
{DestinationDiscoveryCommand}
{BuildCommand}
{TestCommand}
```

| Concern | Binding |
|---------|---------|
| Build success signal | `{BuildSuccessSignal}` |
| Test success signal | `{TestSuccessSignal}` |
| Focused-test selection | `{FocusedTestConvention}` |
| CI configuration / owner | `{CIOwner}` |
| Release automation / owner | `{ReleaseOwner}` |

Do not create a universal command in this file. The consuming repository owns executable checks,
test selection, CI, and release automation. The plugin supplies no parallel verifier/lint/smoke
script and no duplicate CI path.

---

## 5. Dependency and Project-Generation Configuration

| Repository trigger | Repository-owned action |
|--------------------|-------------------------|
| `{DependencyChangeTrigger}` | `{DependencyChangeAction}` |
| `{ModuleIntegrationTrigger}` | `{ModuleIntegrationAction}` |
| `{SourceMembershipTrigger}` | `{SourceMembershipAction}` |
| `{ResourceOrLocalizationTrigger}` | `{ResourceOrLocalizationAction}` |

Populate only real triggers and actions. After source scaffolding, integrate generated sources by
following an existing neighboring target and these repository-owned bindings.

---

## 6. Provider-Native Brain-Flow Configuration

| Concern | Binding |
|---------|---------|
| Default mode | `{BrainFlowMode}` (`co-working` or `auto`) |
| Co-working decisions | human participates in requirements, product/architecture/policy choices, plan, and final finding dispositions |
| Requirements decision | co-working: user approval; auto: independent AI gate decision |
| Plan decision | co-working: user approval; auto: independent AI gate decision |
| Auto eligibility | `{AutoEligibilityPolicy}` |
| Auto interruption threshold | material blocker only; no routine wait/confirm/ask pauses |
| Progress source | approved full-plan checklist + provider-native task state |
| Resume/handoff location | `{ResumeHandoffLocation}` |
| Final AI review | exactly one joined review after semantic Task commits and exact baseline/HEAD/path freeze |
| Final finding disposition authority | `{FinalDispositionAuthority}` |
| Executable tests | repository-owned code tests where behavior/risk warrants them |
| CI/release | consuming repository/DevOps owned |
| Full-auto terminal boundary | engineering completion and release readiness; no implicit push/tag/publish/install/release |

Do not add provider profiles, verifier/lint/smoke scripts, canonical progress schemas, receipts,
manifests, fingerprints, evidence ledgers, or a provider-independent workflow engine. Route relevant
enterprise work through `/ifl-ios-standards:enterprise-ios` and load only the applicable chapters.

---

## 7. Organization Policy Owner Configuration

| Policy | Owner or governed source |
|--------|--------------------------|
| Deployment/platform targets | `{DeploymentPolicyOwner}` |
| Privacy/security | `{PrivacySecurityOwner}` |
| Accessibility | `{AccessibilityOwner}` |
| Observability/operability | `{ObservabilityOwner}` |
| Data retention | `{DataRetentionOwner}` |
| Release sign-off | `{ReleaseSignoffOwner}` |
| Other applicable enterprise policy | `{OtherPolicyOwners}` |

AI may apply a bound policy but may not invent its thresholds, risk acceptance, or sign-off owner.
Any unresolved owner required by the current project is a material setup blocker.

---

## 8. File Trace Header Configuration

| Concern | Binding |
|---------|---------|
| Required | `{TraceHeaderRequired}` |
| Swift/source form | `{SwiftTraceHeader}` |
| Markdown form | `{MarkdownTraceHeader}` |

Do not invent a trace convention. Record the consuming repository's existing rule or `none`.

---

## 9. Git Authority Configuration

| Rule | Binding |
|------|---------|
| Semantic commit cadence | `{SemanticCommitCadence}` |
| Local stage+commit authority | `{CommitAuthority}` |
| Scoped auto-commit scope | `{AutoCommitScope}` |
| Branch creation/switch authority | `{BranchAuthority}` |
| Amend/history rewrite authority | `{RewriteAuthority}` |
| Push/PR/merge authority | `{RemoteGitAuthority}` |
| Tag/publish/install/release authority | `{ReleaseEffectAuthority}` |
| Staging discipline | explicit intended paths only |

Plan approval, auto mode, tests, and final review do not grant Git authority. An explicit scoped
auto-commit instruction covers local stage+commit for conforming semantic tasks only within its
approved plan, repository, worktree, and branch. It never extends to any other operation listed here.

---

## 10. Placeholder Resolution Map

| Placeholder family | Resolution source |
|--------------------|-------------------|
| Identity and destination placeholders | §1, from user + repository evidence |
| Module/path placeholders | §2 + `<BindingsRoot>/PROJECT_STRUCTURE.md` |
| Build/source-boundary placeholders | §3, from repository configuration |
| Commands and success signals | §4, from repository governance |
| Generation triggers/actions | §5, from repository governance |
| Brain-Flow mode | §6, from project/user choice; runtime fallback is co-working |
| Auto eligibility, resume, and disposition | §6, from project/user governance |
| Organization policy owners | §7, from project/organization governance |
| Git and release authority | §9, from explicit project/user governance |
| Per-task module/board names | approved task scope + current structure inventory |

---

## 11. Update Procedure

When a project-wide value changes, update its binding here and the topology inventory when applicable.
Do not scatter project values into plugin standards, examples, skills, or agents. A non-blocking
optional value may be recorded as `TBD`; a required authority, policy owner, identity, or safety
binding must be resolved before setup is complete.
