# Process — Documentation organization

Keep durable product knowledge separate from temporary working material. Do not create workflow
artifacts merely because an agent stage or assignment ended.

## Repository layout

```text
docs/
├── 01-living-docs/       # current PRDs, architecture, ADRs, standards
├── 02-working-docs/      # active plans, research, and work items
├── 03-release-docs/      # release notes and runbooks
└── 99-archive/           # superseded material
```

Use the consuming repository's bound equivalent when it differs.

## Work items

A non-trivial task may use:

```text
docs/02-working-docs/work-items/<WORK-ITEM-ID>-<slug>/
├── requirements.md
├── plan.md
├── review.md             # created only for the single final AI review
└── final-report.md       # optional concise handoff
```

- `requirements.md` owns goal, scope, assumptions, risks, and Definition of Done.
- `plan.md` owns design/architecture decisions, workstreams, task status, and dependencies.
- `review.md` owns the one joined final AI review and accepted/deferred dispositions.
- `final-report.md` is optional and summarizes completion; it must not duplicate the other files.

Do not create verification reports, per-assignment receipts, checkpoint folders, manifests,
fingerprints, evidence ledgers, or artifact trees by default. Use provider-native task state for
ephemeral coordination. Add a separate artifact only when it is itself a user-requested deliverable or
needed by the product domain.

## Placement

- Current product/architecture truth → `01-living-docs/`.
- Active requirements, plans, research, or final review → `02-working-docs/`.
- Release notes/runbooks → `03-release-docs/`.
- Superseded material → matching path under `99-archive/`.

Living documents use stable kebab-case names. Standalone working documents may use
`YYYY-MM-DD-<topic>.md`. ADRs use the consuming project's zero-padded convention.

## Lifecycle

Edit living documents in place. When a working document is complete or superseded, archive it only if
the repository's documentation policy requires retention. Do not maintain append-only audit history in
ordinary agent workflow documents; Git already provides history.

For long documents, use `process/long-document-writing.md`. For execution cadence, use
`process/lean-verification.md`.
