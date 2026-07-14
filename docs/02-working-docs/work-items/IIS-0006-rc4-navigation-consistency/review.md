# Joined Review — IIS-0006 RC4 navigation consistency

## Review identity

- Date: 2026-07-14
- Reviewer: independent agent `iis0006_joined_final_review`
- Frozen range: planning baseline `f910326` exclusive through Task-1 commit `7ecc0c6` inclusive
- Event count: one joined final AI review
- Mode: read-only, non-fail-fast collection; no writer, build, test, verifier, script, CI, network, or
  provider call participated

## Verdict

- Collected findings: `P0/P1/P2 = 0/2/1`
- Material planning reopen: no
- Accepted findings: 3
- Deferred/rejected findings: 0
- Open findings after the one corrective batch: `P0/P1/P2 = 0/0/0`
- Routine re-review: intentionally not run

## Joined findings and dispositions

### F-IIS0006-001 — P1 — Board-originated destination selection

Frozen evidence:

- `ifl-ios-standards/standards/specs/BUS_PATTERNS.md:17-20,30-33,93-95,136,148`
  described weak target binding as sufficient for Board-originated `Bus<Void>` delivery.
- `ifl-ios-standards/standards/specs/COMMUNICATION.md:73-100,165-169` combined a plain targeted
  `returnBus` with the statement that multiple activations share one bus channel.
- `CONTEXT_NAVIGATION.md:224-225` and `REVIEWER_CHECKLIST.md:260-261` already required either one live
  destination or typed destination identity.

Affected authority: `BRD-CTX-001`, ADR-0006, IIS-0006 product decisions 3-5, D1, and D2.

Disposition: accepted and corrected. Weak binding is now explicitly a lifetime rule, not a routing
rule. Plain `Bus<Void>` is limited to intentional fan-out or an enforced one-live-target invariant;
targeted concurrent return carries a stable value-typed destination ID through child input/output and
filters it at the destination. No ViewController reference is fabricated or placed in public IO.

### F-IIS0006-002 — P1 — Protected adopter identity in current work-item text

Frozen evidence: `docs/02-working-docs/work-items/IIS-0006-rc4-navigation-consistency/plan.md:112`
enumerated protected adopter-brand literals while claiming the current output was neutral.

Affected authority: the user's explicit public-brand-removal direction, the work item's content-safety
boundary, and D5.

Disposition: accepted and corrected. The current line now uses the generic classification
`protected adopter-brand string`; this review record does not reproduce the protected literals.

### F-IIS0006-003 — P2 — Compact guidance synchronization

Frozen evidence:

- `ifl-ios-standards/standards/specs/compact/BOARDY_CHEATSHEET.compact.md:7` retained the prior sync
  date/candidate wording.
- The same file at line 185 named `complete(_:)` as an output helper after full/example guidance had
  moved typed output mapping to `sendResult(_:)` and reserved `complete()` for lifecycle release.

Affected authority: D2 and compact/full/example terminology consistency.

Disposition: accepted and corrected. The sync marker identifies the RC4 working candidate, and the
helper rule now uses `sendResult(_:)` while preserving `complete()` for Board lifecycle release.

## Joined lane result

- Canon/ADR meaning, Boardy source, public IO, and framework-neutral Core: unchanged.
- Current/destination ViewController targeting, View-originated source identity, child typed output,
  and build → watch → connect/register → put into context → expose ordering: coherent after the one
  corrective batch.
- Full, compact, examples, composable guidance, context navigation, bus guidance, and reviewer
  checklist: aligned for the approved IIS-0006 boundary.
- Active metadata: unpublished `1.0.0-rc.4`; public Codex marketplace remains pinned to published
  `v1.0.0-rc.1`; Q1-Q6 remain not qualified for RC4.
- Current payload and filenames contain no protected adopter identity; historical refs and
  `.superpowers/` remain outside the candidate and untouched.
- No tooling, verification loop, external Git effect, publication, install, or release authority was
  introduced.

## DoD disposition

| DoD | Result | Basis |
|---|---|---|
| D1 | PASS | Explicit current/destination targets; concurrency now selects by typed identity. |
| D2 | PASS | Coupled lifecycle and communication surfaces agree after one batch. |
| D3 | PASS | Canon, ADRs, source, distribution, and contracts were not changed. |
| D4 | PASS | RC4/RC1/qualification metadata boundaries are explicit and consistent. |
| D5 | PASS | Current output is adopter-neutral; excluded history and unrelated files are untouched. |
| D6 | PASS | One joined review, one corrective batch, no open P0/P1, and no duplicate review/signal. |
| D7 | PENDING | Task-2 candidate commit and closeout-only Task 3 must record immutable identity. |

The commit containing this review, the accepted correction batch, and the D1-D6 state is the immutable
RC4 engineering candidate. `final-report.md` records its exact SHA without modifying candidate payload.
