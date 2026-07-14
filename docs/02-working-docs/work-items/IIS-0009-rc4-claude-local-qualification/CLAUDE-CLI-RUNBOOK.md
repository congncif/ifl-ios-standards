# Direct Claude CLI runbook — RC4 Q2/Q4/Q6

Use this runbook to execute the three remaining qualification rows directly in the already prepared
isolated fixtures. The CLI's configured local-model transport is operator-owned. Authentication state
is not a Standards finding; a row begins only when the CLI reaches inference and loads exact RC4.

## Fixed inputs

```bash
PLUGIN=/private/tmp/iis0009-rc4-candidate/ifl-ios-standards
test "$(sed -n '1p' "$PLUGIN/VERSION")" = "1.0.0-rc.4"
git -C /private/tmp/iis0009-rc4-candidate rev-parse HEAD
```

Expected candidate HEAD:

```text
f7cd2cf87711f1a757d2fbdec5be9be02ee69173
```

Prepared fixtures:

| Row | Working directory | Required baseline |
|---|---|---|
| Q2 | `/private/tmp/iis0009-q2-migration` | `8af9959876c1a130d9e6071d131f13f3a10138fe` |
| Q4 | `/private/tmp/iis0009-q4-enterprise` | `6296c186812011be89e25429f387064e9dedc4a4` |
| Q6 | `/private/tmp/iis0009-q6-enterprise` | `6296c186812011be89e25429f387064e9dedc4a4` |

Before a row, confirm its worktree is clean. Do not reset or clean a fixture that is not clean; inspect
and disposition it first.

Run this exact preflight before the first row:

```bash
CANDIDATE=/private/tmp/iis0009-rc4-candidate
PLUGIN="$CANDIDATE/ifl-ios-standards"
test "$(git -C "$CANDIDATE" rev-parse HEAD)" = "f7cd2cf87711f1a757d2fbdec5be9be02ee69173"
test "$(sed -n '1p' "$PLUGIN/VERSION")" = "1.0.0-rc.4"
test -z "$(git -C "$CANDIDATE" status --porcelain)"
test -z "$(git -C "$CANDIDATE" remote)"
test ! -w "$PLUGIN/VERSION"

test "$(git -C /private/tmp/iis0009-q2-migration rev-parse HEAD)" = "8af9959876c1a130d9e6071d131f13f3a10138fe"
test "$(git -C /private/tmp/iis0009-q4-enterprise rev-parse HEAD)" = "6296c186812011be89e25429f387064e9dedc4a4"
test "$(git -C /private/tmp/iis0009-q6-enterprise rev-parse HEAD)" = "6296c186812011be89e25429f387064e9dedc4a4"
for ROW in \
  /private/tmp/iis0009-q2-migration \
  /private/tmp/iis0009-q4-enterprise \
  /private/tmp/iis0009-q6-enterprise; do
  test -z "$(git -C "$ROW" status --porcelain)"
  test -z "$(git -C "$ROW" remote)"
done
```

No output and exit code `0` means the fixed inputs match. Any non-zero result stops qualification until
the differing input is inspected; do not repair it with reset/clean.

## Recommended direct interactive command

Run rows **sequentially**. Do not set an empty `CLAUDE_CONFIG_DIR`; the local-model transport may depend
on the operator's normal Claude CLI profile. Runtime settings/plugins/MCPs remain isolated by the
command flags, and exact RC4 is supplied explicitly.

For Q2, replace `<ROW_DIR>` with `/private/tmp/iis0009-q2-migration`; for Q4/Q6 use the matching table
entry.

```bash
PLUGIN=/private/tmp/iis0009-rc4-candidate/ifl-ios-standards
cd <ROW_DIR>
claude \
  --plugin-dir "$PLUGIN" \
  --permission-mode bypassPermissions \
  --dangerously-skip-permissions \
  --setting-sources "" \
  --settings '{"enabledPlugins":{}}' \
  --strict-mcp-config \
  --mcp-config '{"mcpServers":{}}'
```

At the prompt, paste the complete matching file:

- Q2: `prompts/q2.md`
- Q4: `prompts/q4.md`
- Q6: `prompts/q6.md`

The prompt requires `/ifl-ios-standards:brain-flow` as the first Standards action. If the CLI cannot
resolve that skill or cannot confirm `1.0.0-rc.4`, stop that session; do not continue with an installed
RC1 plugin or another provider.

## Optional one-shot command

Use this only after the same direct CLI profile is known to reach inference:

```bash
STANDARDS=/private/tmp/ifl-ios-pack-standards-v1
PLUGIN=/private/tmp/iis0009-rc4-candidate/ifl-ios-standards
cd <ROW_DIR>
claude -p \
  --no-session-persistence \
  --output-format text \
  --plugin-dir "$PLUGIN" \
  --permission-mode bypassPermissions \
  --dangerously-skip-permissions \
  --setting-sources "" \
  --settings '{"enabledPlugins":{}}' \
  --strict-mcp-config \
  --mcp-config '{"mcpServers":{}}' \
  < "$STANDARDS/docs/02-working-docs/work-items/IIS-0009-rc4-claude-local-qualification/prompts/<ROW>.md"
```

Replace `<ROW>` with `q2`, `q4`, or `q6`. Do not redirect raw output into the Standards repository.

## Cadence

- Q2 is binding/review-only: no build or test.
- Q4 and Q6 each run exactly one final focused Bazel signal after the complete code change.
- A failed final signal is evidence. Do not rerun it unchanged merely to obtain green output.
- Each row stages explicit paths and creates its own semantic local commit(s).
- Do not push, tag, publish, install a plugin, change remotes, or perform rollout from a fixture.
- Do not rerun Q1, Q3, or Q5; their exact-RC4 passes remain retained.

## Result to return

For each row, return only this bounded summary:

```text
Row: Q2 | Q4 | Q6
CLI version:
Candidate version and exact plugin path:
Invoked Standards skills:
Baseline HEAD:
Changed paths:
Commit SHA(s) and message(s):
Final executable command/result: N/A for Q2; exactly one for Q4/Q6
Worktree clean: yes/no
P0/P1/P2 findings:
Organization-policy handoffs: none, or named decision domains only
Required outcome: PASS / NOT QUALIFIED
Reason:
```

Do not include credentials, source URLs, adopter brand names, protected source, or raw transcripts.

## Pass boundary

- **Q2:** exact RC4/Brain Flow observed; incremental `0.18.x` binding migration; Boardy remains in the
  selected UIKit shell; CocoaPods and product behavior preserved; semantic commit; clean worktree.
- **Q4:** exact RC4/Brain Flow observed with Core/UIKit/SwiftUI only; framework-neutral shared policy;
  humble adapters; no Boardy/package rewrite; semantic commit; one green final Bazel signal; clean tree.
- **Q6:** exact RC4/Brain Flow observed; Boardy/mixed UI/enterprise routing; `2.2.0 → 2.5.0` binding
  migration; handoff/resume and one-writer behavior; bounded public-contract correction; semantic
  commits; one green final Bazel signal; clean tree; organization decisions remain human-owned.

A startup message such as `Not logged in` or an HTTP error before inference is neither a pass nor an
RC4 defect. Correct the operator-owned local CLI route, then start a fresh row session.
