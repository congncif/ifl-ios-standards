# Process — Provider-native full-auto operating model

This document is the single operating contract for Brain-Flow modes. It translates Canon, accepted
ADRs, project bindings, and user authority into provider-native work. It is not a workflow kernel and
does not create product, organization, security, legal, Git, or release authority.

## 1. Terminal boundary

Full auto ends at **engineering completion**:

- the approved Definition of Done is satisfied or a material blocker is recorded;
- every planned semantic task is complete and committed when scoped commit authority exists;
- one frozen review input received one joined final AI consistency review;
- accepted in-scope P0/P1 findings were handled in one corrective batch;
- executable signals actually required by changed code are reported; and
- a factual completion/release-readiness report exists.

Full auto does not imply branch creation/switch, amend/history rewrite, push, PR, merge, tag,
publication, installation, deployment, rollout, or release. Each is a separately governed native
operation.

## 2. Mode selection and transitions

Resolve mode in this order:

1. the user's explicit instruction for the current objective;
2. the consuming repository's bound default;
3. co-working when neither exists.

| Mode | Requirement gate | Plan gate | Execution | Final disposition |
|---|---|---|---|---|
| Co-working | Human approves requirements/DoD | Human approves the complete plan | Continuous; interrupt only for a material decision or missing authority | User participates when requested by “review with me” or equivalent; technical findings remain evidence-led |
| Auto | Independent AI gate | Independent AI gate | Continuous without routine confirmation | Integration owner resolves in-scope technical findings; human-owned policy/authority findings escalate only when material |

A user may switch co-working to auto after approving requirements/DoD, or switch auto to co-working at
any time. A mode switch changes future interaction, not previously granted authority. It never expands
Git, organization-policy, security/legal, or release permissions.

## 3. Auto eligibility and preflight

Auto mode is eligible only when all are true:

- the goal, scope, exclusions, and observable DoD are recorded;
- no unresolved product, UX, API/data, security, money, permission, destructive-scope, or public-
  behavior ambiguity could materially change the result;
- repository/worktree, baseline, branch, relevant project bindings, write boundary, and unrelated
  dirty/untracked paths are known;
- applicable Core, UI/pattern, and enterprise Profiles/chapters can be selected;
- an independent AI reviewer is available for Requirement and Plan gates;
- required implementation tools are available, or safe inline execution is possible; and
- the approved plan does not depend on an unauthorized external effect.

Before mutation, record in the requirements/plan or provider-native task state:

- authority inputs and work-item paths;
- exact in-scope/out-of-scope boundary;
- shared-writer and integration ownership;
- semantic commit authority, if any;
- final technical finding-disposition authority;
- organization-policy owners and unresolved bindings;
- executable commands that belong to the consuming repository, if code may change; and
- a maximum attempt count or timebox for deterministic executable-signal recovery, if code may change;
- the intended final-review baseline/path boundary.

If an eligibility condition is missing and existing repository evidence cannot safely resolve it,
auto is ineligible. Ask the smallest material question or continue in co-working; do not guess or add
a runtime to compensate.

## 4. Authority binding

Treat authority as an explicit matrix, not a single “auto” switch:

| Authority | Valid source | Auto behavior |
|---|---|---|
| Requirements/DoD | Human in co-working; independent AI in eligible auto | Continue after the applicable gate |
| Complete plan | Human in co-working; independent AI in eligible auto | Continue after the applicable gate |
| Technical implementation | Approved plan + repository write boundary | Execute continuously in scope |
| Local stage/commit | Per-operation approval or explicit scoped auto-commit grant | Reuse only within the named plan/repo/worktree/branch |
| Product/public-contract change | Explicit requirements/plan authority | Reopen planning if materially changed |
| Security, privacy, legal, accessibility, retention, observability policy | Named organization policy owner/binding | Apply bound policy; escalate a material missing decision |
| Final technical finding disposition | Named user/project binding in the approved requirements or plan | The integration owner may accept, apply, or defer only within that grant; human-owned policy/risk remains with its bound owner |
| Push/PR/merge/tag/publish/install/release | Exact operation-specific authority | Never infer from mode, gates, tests, or commit authority |

The user or project may constrain any row. A narrower authority always wins for that operation.

## 5. Independent gates

The author of a non-trivial requirements or plan artifact must not approve that same artifact. Use a
read-only provider-native reviewer/subagent with no write assignment for the artifact. If the provider
cannot supply an independent lane, auto is ineligible for that gate; obtain human co-working approval.

### Requirement Gate rubric

`AUTO_APPROVED` requires:

- explicit goal, scope, exclusions, assumptions, risks, and terminal boundary;
- an observable DoD whose items can map to semantic tasks;
- no unresolved material product/security/authority ambiguity;
- no prohibited tooling or hidden external effect; and
- named handling for organization-owned policy decisions.

### Plan Gate rubric

`AUTO_APPROVED` requires:

- every DoD item has one owning semantic task and completion signal;
- dependency order, shared writers, integration owner, and commit boundaries are explicit;
- testing applies only to changed executable behavior and avoids duplicate green signals;
- one exact frozen review-input identity and one final review event are planned; and
- no task silently expands architecture, security, authority, or release scope.

`CHANGES_REQUIRED` returns precise amendments. Apply them as one gate correction and rerun only that
gate. `USER_INPUT_REQUIRED` or a material conflict stops the gate; it is not converted to approval.

## 6. Continuous execution and assignments

- Execute the approved semantic tasks in dependency order.
- Parallelize only disjoint write boundaries. One integration owner owns shared vocabulary, shared
  files, plan state, release metadata, and cross-lane joins.
- An assignment states goal, allowed writes, required inputs, dependencies, output, executable signal,
  and material escalation conditions. Agent completion is not a review or commit boundary.
- If delegation is unavailable or slower than safe inline execution, the integration owner may execute
  inline without changing the plan.
- Apply TDD/testing only to executable behavior where risk warrants it. Documentation-only work has no
  build/test gate.
- After a complete semantic task, stage explicit intended paths and commit once when scoped authority
  exists. Do not request another approval already covered by that grant.

## 7. Failure, recovery, and resume

Classify failure before acting:

| Failure | Recovery |
|---|---|
| Transient provider/tool interruption | Retry the same safe read or reversible operation once; then use one materially different safe path or escalate |
| Deterministic command/test failure | Diagnose the cause, change the affected executable scope, and rerun only the affected signal within the plan/assignment recovery budget; exhaustion is a blocker, not permission to continue looping |
| Specialist unavailable/stalled | Reassign the same disjoint scope or execute inline; do not create a new checkpoint |
| Shared-writer collision | Stop the later writer, preserve both facts, and let the integration owner serialize the edit |
| Context/session loss | Rehydrate from approved requirements/plan, exact last semantic commit, provider-native task state, and current Git status before mutation |
| Unauthorized external effect | Do not perform it; report the required operation and authority |
| Material goal/scope/contract/architecture/security change | Stop this plan and create a new Requirement/Plan decision |

Do not repeat an unchanged failing action, hide a failed signal, or manufacture a verifier. Resume uses
the provider's thread/task state plus durable plan and Git history. A compact handoff, when needed,
contains only work item, approved-plan path, last completed semantic commit, active task, allowed paths,
observed executable signal, and material blocker. It is not a receipt or evidence ledger.

A deterministic recovery budget is a maximum attempt count or timebox bound before execution. It
includes reruns after corrective executable mutations. When exhausted, stop that path and report the
observed failure as a material blocker unless the approved plan explicitly authorizes one different
signal because the original signal itself was proven invalid.

## 8. Frozen review input and engineering-complete candidate

After the last planned pre-review mutation Task commit:

1. stop every writer;
2. record the exact approved authority inputs;
3. record exact baseline and review-input HEAD SHAs;
4. record the explicit included tracked path set and excluded unrelated dirty/untracked paths;
5. ensure every read-only review lane receives that same identity; and
6. keep review outputs and later corrective mutations outside the frozen input candidate.

The joined review covers the complete review-input range and file state, not only the last task. A
dirty file inside the included boundary is either committed before freeze or explicitly included with
its exact state; unrelated user files are never absorbed to make the tree appear clean.

The frozen review input is not the promotion candidate when the corrective batch changes content.
After that batch, record the exact post-correction state. When an authorized semantic commit exists,
its resulting commit is the **engineering-complete candidate**. If commit authority is absent, record
the working-tree state and state that promotion still requires an immutable authorized commit. A
report committed with the correction cannot self-reference its resulting SHA; the provider completion
response or release handoff records that SHA after the commit. RC field qualification and promotion
always use this post-correction engineering-complete identity, never the earlier review-input HEAD.

## 9. Findings and one corrective batch

These are **engineering final-review severities**. `RELEASE.md` owns later RC feedback and qualification
severity. A finding carried from one phase to the other keeps the higher applicable severity and cannot
be silently downgraded merely because its phase changed.

| Severity | Meaning | Default disposition |
|---|---|---|
| P0 | DoD failure, authority/security/correctness blocker, contradictory normative source, or unusable payload | Resolve in scope or block engineering completion |
| P1 | Material architecture, conformance, operability, migration, or adoption defect | Resolve in the one corrective batch; deferral requires the named owning authority |
| P2 | Improvement that does not prevent safe use of the approved result | Defer with rationale/owner or accept when trivially in scope |

The integration owner joins and deduplicates technical findings. It may disposition them only when the
preflight binding grants that role final technical finding authority. In co-working “review with me”
mode, the user participates in final disposition. Product, security/legal policy, release, or other
human-owned findings go to their bound owner; the agent cannot silently accept risk on that owner's
behalf. A missing required disposition grant is a blocker, not implied auto authority.

Apply accepted in-scope P0/P1 findings once. A correction that changes executable code receives only
the smallest affected test/command after mutation; unchanged code does not receive another green run.
Do not schedule a confirmation review. A correction requiring a material goal, scope, public-contract,
architecture, security, or authority decision requires a new approved plan.

## 10. Completion report

Report only observed facts:

- DoD status and any blocker;
- semantic task commits, exact frozen review-input identity, and the post-correction
  engineering-complete candidate identity or explicit pending-commit state;
- joined findings and dispositions;
- executable signals actually run and whether Task 5 changed code;
- deferred items with owner/trigger;
- external/release operations not performed; and
- the next separately authorized action, if any.

Do not claim CI, release, publication, installation, field qualification, or organization sign-off
that was not actually observed.
