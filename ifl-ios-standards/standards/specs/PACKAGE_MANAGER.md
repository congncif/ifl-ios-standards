# Package Manager and Build-System Boundary

## Decision

The Standards are package-manager- and build-system-neutral. Canon defines module/target boundaries,
visibility, dependency direction, composition, and supply-chain obligations. The consuming repository
chooses and binds the mechanism that realizes them.

Supported bindings include CocoaPods, SwiftPM, Bazel, and documented mixed arrangements. This is a
semantic compatibility statement, not a promise that every example, generator, or provider exposes
identical manager-specific features.

## Binding contract

Project bindings in `CLAUDE.md`, `AGENTS.md`, or an equivalent repository-owned configuration identify:

- package manager(s), build system, workspace/project, scheme, and module root;
- Interface/contract and Implementation/Plugins target names;
- target labels or dependency syntax and normal build/test commands;
- organization-owned dependency, provenance, vulnerability, license, and release policies.

Across every manager:

- consumers depend on the public Interface/contract target, not the Implementation/Plugins target;
- implementation targets may depend on contracts they implement or consume; contract targets do not
  gain reverse dependencies on their implementations;
- composition roots own concrete wiring;
- manager-specific syntax cannot weaken selected Canon Profiles or Rules.

For Boardy/VIP details, use `ARCHITECTURE.md`, `IO_INTERFACE.md`, `MODULE_CREATION.md`, and
`PLUGINS_INTEGRATION.md`. For dependency selection and organization policy, use `SDK_FIRST.md` and
`../enterprise/supply-chain-legal.md`.

## Manager-specific material

Examples and scaffolders may show a podspec, `Package.swift`, `BUILD` target, or hybrid wiring. Treat
that material as an adapter example:

- prose states the architectural concept in manager-neutral terms;
- manager syntax stays local to the example or operational guide;
- a consuming project translates the example into its bound build graph;
- the presence of one adapter does not make that manager mandatory or make other adapters unsupported.

If a tool supports only one manager, its documentation must say so. The limitation belongs to that tool,
not to the architecture standard.

## Changing or adding a manager

A project-local binding change does not require a Standards ADR when canonical boundaries and behavior
remain unchanged. A pack-wide change requires a governed ADR when it changes public scaffolder behavior,
support commitments, target semantics, dependency direction, or compatibility. Classify and release the
change under `../GOVERNANCE.md`, including migration and affected derived documents.

The Standards do not prescribe a universal lockfile, registry, mirror, version, checksum, license
classification, remediation window, or release threshold. Apply the actual manager's authoritative
resolution state and the consuming organization's human-owned supply-chain/legal policy; do not invent
missing values.

## Migration from the historical CocoaPods pin

The former `0.x` policy treated CocoaPods as the pack-wide default. For `1.0.0-rc.1`:

1. Keep existing CocoaPods wiring if it satisfies Canon; no conversion is required.
2. Keep or adopt SwiftPM, Bazel, or a mixed arrangement through project bindings.
3. Translate podspec-specific prose into target/dependency concepts when applying an example elsewhere.
4. Escalate only semantic gaps or tool limitations; manager choice alone is not an architecture
   exception.

See `../COMPATIBILITY.md` for the complete `0.18.x` adoption path.
