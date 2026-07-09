# Process — Docs Organization

**Trigger:** Whenever you create any project document (plan, spec, ADR, PRD, report, handoff, issue, feature request, design note), or when a tool/skill proposes a document path.

Project documents live with the code they describe — in-repo, version-controlled, classified — so they are reviewable and discoverable. They are never written to machine-global locations.

## 1. Principle
- All project docs go under the repo's `docs/` tree, classified by durability (top-level bucket) and type (inner folder).
- **Never** write project docs to `~/.claude/`, the home directory, OS temp, or any path outside the repo. Those are machine-global — not shared, not version-controlled with the code.
- Deviate from this layout **only on explicit user request**.

## 2. The layout

```
docs/
├── 01-living-docs/    # durable truth — edited in place, NO date prefix, stable kebab names
│   ├── product/          # PRD, vision, scope, roadmap
│   ├── architecture/     # tech design, system overview, diagrams
│   ├── adr/              # Architecture Decision Records — NNNN-kebab-title.md
│   ├── data/             # data model, schema, ERD, ownership
│   ├── design-system/    # design tokens, component inventory, UX/UI guidelines
│   ├── integrations/     # external-service contracts, API/dependency maps
│   └── config/           # configuration & environment reference
├── 02-working-docs/   # session/ephemeral — DATE-prefixed YYYY-MM-DD-<topic>.md
│   ├── plans/            # implementation plans (incl. tool / superpowers output)
│   ├── specs/            # design specs / brainstorm output
│   ├── research/         # spikes, investigations
│   ├── reports/          # review / audit / coverage reports
│   ├── handoffs/         # briefing-handoff artifacts
│   ├── issues/           # bug write-ups, incident notes
│   └── feature-requests/ # feature-request write-ups
├── 03-release-docs/   # release-time artifacts
│   ├── release-notes/    # per-version notes (vX.Y.Z.md)
│   └── runbooks/         # deploy / rollback / on-call
└── 99-archive/        # superseded docs; mirror original sub-path, prefix archived date
```

Inner subfolders are create-on-demand — only the bucket a document belongs in must exist when that document is created.

## 3. Routing rules
1. Tool/skill output (e.g. superpowers brainstorming specs and plans) is redirected from its `docs/superpowers/specs|plans` default into `docs/02-working-docs/specs` and `docs/02-working-docs/plans`. Declare this override in the host `CLAUDE.md`/`AGENTS.md` so the skill writes there.
2. ADRs → `docs/01-living-docs/adr/`. PRD, architecture, data design, design-system, integration, and config docs → the matching `01-living-docs/*` folder.
3. Plans, specs, research, reports, handoffs, issues, feature requests → the matching `02-working-docs/*` folder.
4. Release notes and runbooks → `03-release-docs/*`.

## 4. Naming
- **Living docs:** stable kebab-case, NO date prefix — edited in place as the single current truth.
- **Working docs:** `YYYY-MM-DD-<topic>[-kind].md` — dated because point-in-time and cumulative.
- **ADRs:** `NNNN-kebab-title.md`, zero-padded sequential.

## 5. Lifecycle
- A working doc that is completed or superseded moves to `99-archive/<original-bucket>/…` (same name, archived-date prefix).
- A living doc is edited in place; when retired, it is archived the same way.

## 6. Long generated documents

For long generated documents (briefings, plans, specs, reports, ADR drafts, research notes, migration
guides), follow `process/long-document-writing.md`:

- create a skeleton first;
- write one major section per chunk;
- keep section-local status truthful;
- use correction sections for append-only artifacts;
- write or correct the final report after final verification.

## Verification

This process is being followed when:
- Every new doc sits inside the repo `docs/` tree (not global, not repo-root scatter).
- Its path matches its type (durability bucket + inner folder).
- Tool-generated plans/specs land in `docs/02-working-docs/`, not `~/.claude/` or `docs/superpowers/`.

## See also
- `process/lean-verification.md` — checkpoint cadence for plan execution.
- `process/long-document-writing.md` — chunk-safe writing for generated plans, specs, reports, and handoffs.
- `process/README.md` — the process-doc index, when present.
