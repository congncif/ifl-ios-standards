<!-- Created by claude-sonnet-4-6 on 2026-05-18 -->
<!-- brain-version: 1.0.0 · last-updated: 2026-05-18 -->

# Appendix B — Generic Authoring Conventions

- New source files carry a one-line authorship trace header per project convention.
- File names match the primary type name.
- Imports are grouped: platform → architecture primitives → project modules.
- Public symbols document their intent with one-sentence comments only when name alone is insufficient.
- Errors are typed; never throw `NSError` from new code.

