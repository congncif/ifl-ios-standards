---
name: io-interface
description: >-
  Use when defining or changing a Boardy module's public IO surface — BoardID constants,
  InOut models (Input/Output/Command/Action), the MainDestination/io factory, or ServiceMap
  accessors. Triggers: "define IO interface", "add a BoardID", "InOut types", "ServiceMap accessor".
---

# IO / BoardID / InOut / ServiceMap

## Read
- `${CLAUDE_PLUGIN_ROOT}/standards/specs/compact/BOARDY_CHEATSHEET.compact.md` — IO skeleton + naming tables (read first).
- `${CLAUDE_PLUGIN_ROOT}/standards/specs/IO_INTERFACE.md` — full reference (on demand).
- `${CLAUDE_PLUGIN_ROOT}/standards/specs/EXAMPLES_IO.md` — worked example.

## Invariants
- IO module is `public`; everything in `IO/**` is the cross-module contract.
- Other modules import **only** this IO target — never `{Module}Plugins`.
- BoardID strings follow the `pub.mod.{Module}.{Board}` convention (see QUICK_REF §2 for prefix rules).
- Naming with an optional project prefix (e.g. `DAD`): prefix public-facing identifiers
  (module, ServiceMap class/accessor); VIP class names stay no-prefix. See QUICK_REF §2.

## Shape
`IO/{Board}/`: `{Board}IOInterface.swift` (BoardID + `{Board}MainDestination` + `io{Board}` factory),
`{Board}InOut.swift` (Input/Output/Command/Action), `ServiceMap+{Board}.swift` (accessor on `{Module}ServiceMap`).
