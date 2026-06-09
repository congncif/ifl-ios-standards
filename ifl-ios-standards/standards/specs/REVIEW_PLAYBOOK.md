# REVIEW_PLAYBOOK — procedural runbook for Boardy+VIP code review

> **Purpose**: step-by-step procedure for reviewing a Boardy+VIP PR. `REVIEWER_CHECKLIST.md` is the *reference* — exhaustive itemized list of rules to check. This playbook is the *procedure* — the order to check them in, how to categorize what you find, comment templates that match the recurring issues, and when to escalate vs. block.
>
> **Not a pattern spec.** Exempt from the 12-section `SPEC_CONTRACT.md` template; this is a procedural runbook, same as `DECISION_TREES.md` / `BROWNFIELD_MIGRATION.md` / `GREENFIELD_SETUP.md` / `TROUBLESHOOTING.md`.
>
> **Use this when**: you've been asked to review a PR. **Don't use this for**: writing code (use `DECISION_TREES.md` + pattern specs) or debugging (use `TROUBLESHOOTING.md`).

---

## Triage order — read the PR in THIS sequence

Reviewer fatigue degrades quality as files pile up. Most reviews silently follow GitHub's file-tree order, which is alphabetical — useless. Use this order instead.

| # | Read | Why first |
|---|------|-----------|
| 1 | PR description | If the goal isn't clear, stop and ask. Never review code whose intent you can't restate. |
| 2 | lint output (CI badge) | If lint fails, the PR isn't ready. Don't review further until green. |
| 3 | `Podfile` + every `*.podspec` diff | Module structure decisions cascade. A wrong podspec dep contaminates downstream files. |
| 4 | `IO/**` diffs (new + modified) | IO is the public surface. Mistakes here are breaking changes. |
| 5 | `Sources/Plugins/**` diffs | ModulePlugin + LauncherPlugin + construction wiring. Wiring mistakes cause runtime crashes the tests won't catch. |
| 6 | `Sources/Microboards/**` Board + Builder | Board orchestrates; Builder is the composition root. Read these before reading the VIP triad. |
| 7 | Interactor + Presenter + ViewController | The VIP triad. By now you understand the wiring; you can focus on logic placement. |
| 8 | `Sources/Services/**` (Domain, Application, Infra) | Service layer. Read last because the Board/VIP work above tells you what the service contract needs to support. |
| 9 | Tests | After reading impl, ask: do tests cover the failure modes the impl introduces? |

If the PR is large (>500 lines), stop at step 4 and request a split. Reviews of large PRs are not reviews — they're rubber-stamping.

---

## Categorize every finding — three tiers

Tag each comment with one of these. Don't mix them.

| Tier | Meaning | Examples |
|------|---------|----------|
| 🛑 **Blocker** | Must be fixed before merge. Wrong semantics, security issue, architecture violation, breaks production. | Domain layer imports UIKit. Board stores `weak var view` (should be Presenter's job). Public BoardID renamed (breaking). Force-cast that can fail at runtime. |
| ⚠️ **Major** | Should be fixed before merge but won't block release. Style/structure drift that compounds, missing tests for a non-trivial path, soft API mistake. | Interactor calls Presenter with `ViewModel` instead of domain model. Bus subscription without identity filter. `attachObject` without paired `complete()` / `detachObject`. |
| 💡 **Nit** | Author's call. Style preferences, naming, redundancy. Use sparingly — nit pile-ups exhaust reviewers' credibility on Blockers. | Variable name. Comment phrasing. One-line refactor. Order of properties. |

Rule of thumb: if you'd block YOUR OWN PR on this finding, it's a Blocker. If you'd merge YOUR OWN PR with this and fix in a follow-up, it's Major or Nit.

---

## Comment templates — by recurring issue

When you find one of these, paste the template (or a close variant). Templates land the SAME way every time, which trains authors and saves typing.

### Architecture — wrong layer

```
🛑 Blocker — Domain leak.

Domain layer must be pure Swift — no UIKit, Boardy, networking, or vendor SDK imports.
This file is under `Sources/Services/Domain/` and imports `{Framework}`.

Fix: move the {UIKit/Boardy/SDK}-typed value to {Presenter ViewModel / Infra DTO}.
Ref: LAYERING.md §Domain, TROUBLESHOOTING.md §1.1.
```

### Architecture — wrong direction

```
🛑 Blocker — VIP flow direction.

The flow is one-way: ViewController → Interactor → UseCase → Presenter → ViewController.
This change has {VC calling Presenter directly / Presenter calling Interactor / etc}.

Fix: route via Interactor. Exception is pure-navigation intents from VC → ActionDelegate (Board).
Ref: VIP_COMPONENTS.md, QUICK_REF.md rule 2.
```

### Board state

```
🛑 Blocker — Board state leak.

Board must be stateless — no stored input / context / flags. All per-activation state lives in the Controller (or in `activate()` locals).
This adds `private var {field}` on the Board.

Fix: move {field} to Controller (or pass through `activate()` to the Builder).
Ref: BOARDY_FOUNDATIONS.md §Board lifecycle ≠ Controller lifecycle, REVIEWER_CHECKLIST §Architecture.
```

### Board → Controller via stored reference

```
🛑 Blocker — Board→Controller via stored reference.

Board must communicate with Controller via event buses, not stored controller references.
This stores/retrieves a controller reference.

Fix: declare `private let {action}Bus = Bus<{Payload}>()`. Connect in `activate()`:
  bus.connect(target: controller) { ... }
Transport from Board: `bus.transport(input: value)`.
Ref: COMMUNICATION.md, REVIEWER_CHECKLIST §Viewless Board.
```

### Bus identity filter missing

```
🛑 Blocker — Round-trip bus without identity filter.

This is a round-trip bus (Controller → Board → SDK → bus → Controller). Without an identity
filter every Controller instance subscribed to this bus will receive the message.
Closing over a local controller variable does NOT filter — it's a different reference per activation.

Fix: bus payload must carry source Controller:
  let bus = Bus<(source: {Controller}, payload: T)>()
Subscriber: `guard target === msg.source else { return }`.
Ref: BUS_PATTERNS.md §Round-trip identity-filtered, QUICK_REF.md rule 13.
```

### IO public/internal violation

```
🛑 Blocker — IO public surface violation.

Top-level types under `{Module}/IO/**` must be `public`. The lint
(`io_visibility.swift`) flags this as `IO-missing-public`.

Fix: prepend `public` to {type}. If the type is only used inside the module, move it
to `Sources/Microboards/{Board}/` instead of marking it `public` in IO.
Ref: IO_INTERFACE.md, TROUBLESHOOTING.md §1.4.
```

### Public symbol in Sources (not in Plugins/)

```
🛑 Blocker — public symbol outside the public-export zone.

`Sources/**` is `internal` EXCEPT `Sources/Plugins/**` (LauncherPlugin + construction wiring).
This file is under `Sources/Microboards/**` / `Sources/Services/**` and declares `public {type}`.

Fix: drop the `public` modifier. If the type really must be public (App constructs it for
LauncherPlugin init), move it to `Sources/Plugins/{Module}{Feature}…swift`.
Ref: IO_INTERFACE.md §"Domain meaning vs construction wiring", TROUBLESHOOTING.md §1.5.
```

### Provider config misplaced

```
⚠️ Major — provider configuration location.

Provider configurations are CONSTRUCTION WIRING, not domain meaning. They live next to the
LauncherPlugin under `Sources/Plugins/`, not in `IO/`. Clients never reference them; only
App-boot wiring does.

Self-test: does a client module call this to USE the feature, or does App call this to BOOT
the feature? Boot → Sources/Plugins/. Use → IO/.

Fix: move {file} from `IO/` to `Sources/Plugins/`. Drop the IO `import` from any client.
Ref: EXTENSIBLE_PROVIDER.md §"Why provider configurations live in Sources/Plugins/, not IO/",
DECISION_TREES.md Tree §7.
```

### BoardID rename (breaking)

```
🛑 Blocker — BoardID rename is breaking.

Public BoardIDs are runtime contracts. Renaming `{old}` → `{new}` will silently break every
caller that activates this Board by literal — they'll hit `BoardID not registered` at runtime.

Fix: either revert the rename, OR add a literal alias in IO:
  public extension BoardID { static let {old}: BoardID = .{new} }
  // keep both for one release; remove `{old}` after callers migrate.
Confirm zero callers (`grep -r '"{old}"' submodules/`) before the eventual removal.
Ref: IO_INTERFACE.md §Lifecycle, TROUBLESHOOTING.md §2.3.
```

### `registerFlows()` in `activate()`

```
🛑 Blocker — registerFlows() must run in init, not activate().

`activate()` runs once per activation; `registerFlows()` registers permanent flow listeners.
Running it in `activate()` either re-registers on every call (duplicate handlers) or fails
silently if guards prevent re-registration.

Fix: move the call to `init`. Boards reuse instances across activations; flow registration
must outlive any single activation.
Ref: QUICK_REF.md rule 7, BOARDY_FOUNDATIONS.md.
```

### `attachObject` without release

```
⚠️ Major — attachObject without explicit release.

`attachObject(controller)` extends the Board's lifetime to the controller. Without a paired
`complete()` (single-session) or `detachObject(controller)` (multi-session), re-activations
stack controllers on subscribed buses → duplicate handler firings per event.

Fix: pick one based on Board intent:
- Single-session: call `complete()` once the work is done.
- Multi-session: call `detachObject(controller)` when the controller is no longer needed.
Ref: MICROBOARD_NONUI.md §Attach context, REVIEWER_CHECKLIST §Viewless Board.
```

### Concurrent BlockTaskBoard with `.flow`

```
🛑 Blocker — concurrent BlockTaskBoard with .flow.addTarget.

`.flow` is shared across concurrent activations. For `.concurrent` execution mode, results
cannot be matched back to their originating activation through `.flow`.

Fix: use parameter callbacks per call site:
  board.activate(input, onSuccess: { ... }, onError: { ... })
Ref: QUICK_REF.md rule 14, EXAMPLES_NONUI_BOARDS.md §BlockTaskBoard.
```

### Missing test for a non-trivial path

```
⚠️ Major — uncovered failure path.

This {function/branch} handles an error case ({describe}) but no test exercises it.
The path is non-trivial — silent regressions here are hard to spot.

Fix: add an Interactor (or UseCase) test that drives this path. Mock the Repository / UseCase,
assert the Presenter receives the expected error mapping.
Ref: TESTING.md §What to test.
```

### Nit examples (use sparingly)

```
💡 Nit — naming. `processData` is generic; the function processes orders specifically.
Suggest `applyOrderDiscount` or similar. Author's call.
```

```
💡 Nit — order. New properties usually go below `private let builder:` to keep the wiring
group together. Author's call.
```

---

## What to skip

These come up in every review but are NOT worth your time as a reviewer:

- **Formatting / whitespace** — let the formatter handle it. If the formatter passes, move on.
- **Auto-generated files** (`Pods.xcconfig`, `*.pbxproj`) — read for unintended changes (target removed, dep version bump) but don't review the syntax.
- **Issues the lint already flagged** — the author can read the CI output. Don't restate every lint failure as a review comment.
- **Style preferences without a rule** — if `QUICK_REF.md` / specs don't mandate it, it's a Nit at most. Don't argue style.
- **Architecture decisions that are already in DECISION_TREES.md** — if the author picked a valid path (e.g. `flow` Board vs `viewless` for a routing case), don't second-guess unless they picked the wrong path.

---

## Escalate when

You can't review a PR — escalate instead of approving on faith.

| Situation | Escalate to |
|-----------|-------------|
| The PR description doesn't explain the intent and you can't infer it | Author — ask for a description rewrite |
| The PR changes a pattern the pack doesn't yet codify (new Board type, new bus shape) | Architecture owner — propose a spec ADR before merging |
| The PR touches a module owned by a team you're not on, and the change isn't trivial | Module owner — they should be a required reviewer |
| The diff is >500 lines or spans more than 3 modules | Author — request a split into smaller PRs |
| A Blocker reveals a wider problem (e.g. a violation that probably exists elsewhere too) | Document the discovery in `TROUBLESHOOTING.md` or `17-anti-patterns.md` after the PR is fixed |

Don't approve a PR you genuinely can't evaluate. "LGTM" on a PR you didn't understand is a future incident.

---

## Approve / request-changes — the actual decision

| Outcome | When to use |
|---------|-------------|
| **Approve** | Zero Blockers, Majors acknowledged or fixed, Nits author's call. CI green. |
| **Approve with comments** | Same as Approve but you want the author to see Nits / future-work notes. Do NOT use this for Majors — request changes instead. |
| **Request changes** | At least one Blocker, OR multiple Majors that change the impl shape. State the Blocker(s) explicitly in the review summary. |
| **Comment** | You're not the gating reviewer but want to flag something. Don't use Comment when you ARE the gating reviewer — it leaves the PR in limbo. |

Summary template for "request changes":

```
Requesting changes — {N} blocker(s), {M} major(s).

🛑 Blockers:
- {file}:{line} — {one-line summary}
- {file}:{line} — {one-line summary}

⚠️ Majors:
- {file}:{line} — {one-line summary}

Once the blockers are addressed I'll re-review the {N} affected files; the rest can stay
unchanged unless you want to address the majors in this PR vs. a follow-up.
```

Summary template for "approve":

```
LGTM — {N} nit(s), zero blockers.

Highlights:
- {what went well — be specific; "good test coverage" is generic, "the UseCase test for the
  partial-failure path is exactly the case I would have flagged" is useful}.

Nits inline; author's call.
```

---

## Re-review etiquette

When the author pushes fixes:

- **Look at the diff since your last review** — GitHub's "Changes since you last reviewed" view. Don't re-read the entire PR.
- **Resolve threads you opened** when the fix lands — don't make the author chase your acknowledgement.
- **Don't introduce new Blockers in a re-review** unless the fix itself introduces them. New issues that existed in the original PR but you missed → Major or Nit, not Blocker; flag and either approve with a follow-up note or open a separate issue.

---

## Anti-patterns

- ❌ **"LGTM" without reading** — if you didn't read every diff hunk, you didn't review. Either review or recuse.
- ❌ **Nit avalanche** — 30 Nits + 1 Blocker is worse than 1 Blocker. Buries the signal.
- ❌ **Reviewing in the GitHub UI for large PRs** — pull locally, open in Xcode, navigate by symbol. UI-only review misses cross-file consistency.
- ❌ **Pattern arguments mid-PR** — if you disagree with a pattern choice the pack codifies, raise it as a spec ADR. Don't relitigate on every PR.
- ❌ **Conditional approval** — "approve assuming you address the comments". If they're Blockers, request changes; if they're Nits, approve cleanly. Conditional approval is just unclear intent.
- ❌ **Reviewing your own design** — if you co-designed the impl with the author, your review is biased. Find a fresh reviewer.

---

## Pre-flight checklist for the reviewer (yourself)

Before opening the PR:

- [ ] You've read `QUICK_REF.md` recently (this month).
- [ ] You know which modules the PR touches and whether you can credibly review them.
- [ ] You have 30+ minutes of uninterrupted time. Reviews done in 5-minute chunks miss cross-file issues.
- [ ] CI on the PR is green (lint passes). If red, return to author before reviewing.

---

## References

- `REVIEWER_CHECKLIST.md` — exhaustive rules reference; this playbook's companion.
- `DECISION_TREES.md` — pattern selection; cite when an author picked the wrong tree.
- `TROUBLESHOOTING.md` — symptom → fix; cite when a Blocker has a known fix recipe.
- `QUICK_REF.md` §4 — the 14 hard rules; most Blocker citations land here.
- `17-anti-patterns.md` — rulebook anti-pattern catalog; cite when the author's change reintroduces a known anti-pattern.
- `COMMIT_WORKFLOW.md` — pack-side commit/push approval rules; reviewer enforces these on merge.
- `BRIEFING_HANDOFF.md` — if review is being run by `ios-reviewer` agent, this is the briefing format.
