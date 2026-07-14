# Process — Plan-scale delivery and final AI consistency review

**Trigger:** Use when planning or executing a non-trivial change through Brain-Flow.

Use `full-auto-operating-model.md` for eligibility, authority, recovery/resume, exact candidate
identity, finding disposition, and the engineering-completion boundary.

## Core rule

Complete one approved plan before running one final AI consistency review. Internal workstreams,
agent assignments, files, layers, and findings are not review or verification boundaries.

The plugin does not ship or require verifier, lint, smoke, manifest, fingerprint, receipt, or gate
scripts. Do not recreate those mechanisms in shell, Swift, schemas, prompts, or work-item artifacts.
Provider-native task/thread state coordinates the work; the repository and approved plan remain the
source of truth.

## Planning contract

One plan defines:

- the goal and measurable Definition of Done;
- the complete in-scope and out-of-scope boundary;
- design and architecture decisions;
- dependency-ordered workstreams and shared-writer ownership;
- code changes that require tests and documentation/configuration changes that do not;
- semantic task boundaries for traceable commits;
- the final AI review coverage needed to judge the whole result.

Use workstreams and slices only to organize execution. Split them by domain semantics, user story,
dependency, or impact. Do not create a checkpoint because a file, agent assignment, test, or finding
ended. Reopen the plan only when the goal, scope, public contract, architecture, security boundary, or
material product behavior changes.

## Execution contract

1. Execute every workstream in dependency order; parallelize only disjoint writers.
2. Read before writing and keep the smallest correct change inside the approved scope.
3. For executable production code, use the consuming repository's normal development tests. Apply
   TDD only to code where behavior or regression risk warrants it. Documentation, standards text,
   schemas used only as documentation, metadata, and templates do not require TDD.
4. Do not add plugin-owned verification scripts or duplicate CI. CI and release automation belong to
   the consuming organization/DevOps boundary.
5. Commit by complete semantic task when separately authorized so history stays reviewable and
   traceable. A work slice, file, finding, or generated artifact is not a commit boundary.
6. Keep progress minimal: update the approved plan's task list or provider-native task state. Do not
   create parallel state machines, canonical progress schemas, evidence ledgers, manifests, hashes,
   or per-step reports.
7. Continue until the entire plan and Definition of Done are implemented. Do not stop for routine
   approval, review, or verification cycles in auto mode.

## Representative configuration selection

For executable changes, default to the smallest representative set that covers all three dimensions:

1. the changed behavior;
2. the common supported configuration for each affected platform; and
3. every directly impacted configuration-specific build surface.

Do not enumerate every configuration permutation unless the approved Definition of Done or a bound
project/release policy explicitly requires it. Each additional signal must close a distinct risk; do
not collect equivalent green results from multiple build systems, destinations, or variants.

- **iOS example:** select the affected or common scheme and destination, plus an impacted package or
  build-system path only when it exercises a distinct changed surface. Do not test every scheme,
  simulator, package manager, and build-system permutation by default.
- **Android example:** select the default/common build variant plus the directly impacted build type or
  product flavor. Do not test every flavor × build-type permutation by default. This is portable
  verification-selection guidance, not an Android architecture or compatibility claim by this pack.

Expand the set only when observable risk requires it: configuration/build logic changed; platform or
toolchain behavior changed; the change crosses configuration-specific code; bound policy or release
risk requires broader coverage; or a failure proves the current representative set insufficient.

A nonstandard configuration may be waived only by a named user/project owner with authority over that
boundary, when an accepted representative platform signal is bound to the same exact implementation or
candidate state. Record the omitted boundary, accepted signal, rationale, coverage that remains
unproven, residual risk, and owner. A waiver never converts unobserved target-specific coverage into a
green result and never hides or downgrades P0/P1 evidence.

## Single final AI review

Run exactly one AI consistency review after the last planned Task commit. Freeze and record the
approved authority inputs, exact baseline and candidate HEAD SHAs, explicit included tracked paths,
excluded unrelated paths, and writer stop. Review outputs and later corrections are outside that input
identity. Review the complete frozen range/state against the approved plan and Definition of Done.

The review may use parallel specialist lanes, but all lanes are one review event over the same final
candidate. Collect all findings before any remediation. Cover at least:

- requirements and Definition-of-Done completeness;
- architecture, dependency direction, API and Boardy+VIP consistency;
- terminology, cross-reference, template, example, and package consistency;
- security, privacy, accessibility, testing guidance, migration, and enterprise-policy consistency;
- removal of obsolete tooling paths and absence of dangling references.

Return one joined finding list with severity, evidence, and recommended disposition. Apply accepted
in-scope findings in one corrective batch. Do not schedule routine re-review, per-finding review, or
duplicate green-signal runs. If the batch changes executable code, run only the smallest affected
signal. A corrective change that materially changes goal, scope, public contract, architecture,
security, or authority becomes a new plan; it is not another loop inside the completed plan.

## Completion and Git authority

After the corrective batch, report the final Definition-of-Done status, accepted/deferred findings,
changed semantic tasks, and any real blocker. Do not claim that AI review replaces executable-code
tests required by the consuming project; it replaces plugin-owned consistency tooling and repeated
workflow gates.

Plan approval, auto mode, review completion, and test success never grant Git authority. Staging,
committing, pushing, tagging, publishing, and releasing remain distinct native operations requiring
the authority defined by project governance. An explicit scoped auto-commit grant is reusable only for
the named semantic tasks/repository/worktree/branch; it grants no other operation.

## Prohibited reintroductions

- verifier/lint/smoke scripts bundled with this plugin;
- per-checkpoint RR/G gates, manifests, fingerprints, receipts, or evidence ledgers;
- a custom workflow kernel or provider-independent runtime state machine;
- execute → review → fix → re-review loops for small findings;
- build/test reruns on unchanged code merely to obtain another green signal;
- splitting one semantic outcome into administrative checkpoints.

If a process proposal needs any of these, place it in the post-1.0 tooling backlog instead of the
Standards 1.0 delivery path.
