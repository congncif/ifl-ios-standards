# Process — Long Document Writing

**Trigger:** Whenever you create or update a long generated document such as a briefing, plan, spec,
ADR draft, report, research note, migration guide, or handoff artifact.

Long documents are easy to corrupt when generated in one large write: sections go missing, final
status becomes stale, and append-only audit trails get rewritten accidentally. Write them in small,
reviewable chunks.

## 1. When to chunk

Use section-by-section writing when any of these is true:

- the document has more than 5 major sections;
- the document is expected to exceed roughly 120 lines;
- the document contains multiple statuses or gate verdicts;
- the document is append-only or used as an audit trail;
- different stages/agents own different sections;
- verification will happen after an initial report draft.

Short single-section docs may be written in one operation, but still follow the docs organization
rules for path and naming.

## 2. Chunk-safe writing pattern

1. **Create a skeleton first.** Write only the title, metadata, and section outline.
2. **Append one major section at a time.** Treat each `##` section as the default chunk boundary.
3. **Finish each chunk before starting the next.** A chunk should be internally coherent and should not
   depend on future text to make its status truthful.
4. **Keep status markers local.** If a section ends with `STATUS:`, that status must be true at the time
   the section is written.
5. **Use corrections instead of rewrites for audit docs.** For append-only artifacts, never edit a prior
   section to update facts. Append `## Correction — {section}` or `## {section} v{n}`.
6. **Write final status last.** Do not write a final report before the final verification command has
   actually run. If this happens, append a correction section after verification.
7. **Verify after the last chunk.** Run the cheapest sufficient document check, usually
   `git diff --check` plus any project markdown lint/sanity check.

## 3. Recommended briefing order

For `docs/02-working-docs/handoffs/{task-slug}/briefing.md`:

1. Create skeleton: title, `## Meta`, and a section checklist.
2. Append `## Requirement summary`.
3. Append `## Requirement gate`.
4. Append `## Implementation plan`.
5. Append `## Plan gate`.
6. Append `## Implementation report`.
7. Append `## Test report` or `## Test / Verification report`.
8. Append `## Review report`, if review ran.
9. Run the final verification/checkpoint.
10. Append `## Final report` with final verified facts.

If final verification runs after `## Final report` was drafted, append:

```markdown
## Correction — Final report
- Final verification command: {command}
- Result: {passed|failed with summary}
- Remaining work: {list or none}

STATUS: {READY|BLOCKED|INFO_REQUIRED}
```

## 4. Ownership and concurrency

- Each stage/agent owns only its section.
- Do not rewrite another stage's section to make the document read more smoothly.
- If a prior section is wrong, append a correction with the source of the correction.
- If multiple agents are writing, the orchestrator serializes writes; no two agents write the same
  document at the same time.

## 5. Tooling notes

- Prefer an append/insert operation for later chunks when the tool supports it.
- If the only available operation overwrites the whole file, first read the current file, preserve all
  existing content exactly, then write the new content with the next chunk appended.
- Never paste a large source dump into a handoff. Cite paths and line numbers instead.
- After each write, do not re-read only to check that the tool worked; rely on the tool result. Re-read
  only when you need the current file content to append or resolve a conflict.

## Verification

This process is being followed when:

- long generated docs are created from a skeleton and appended section-by-section;
- append-only docs use correction sections instead of rewriting old facts;
- final status is written after final verification, or corrected afterward;
- a final document check runs after the last chunk.
