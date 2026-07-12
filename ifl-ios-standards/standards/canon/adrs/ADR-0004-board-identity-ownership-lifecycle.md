# ADR-0004 — Board identity, ownership, and lifecycle

- Status: In review
- Decision date: 2026-07-13
- Owner: iOS Profile Owner

## Context

Board identifiers are cross-module contracts, while UI, viewless, flow, and block-task boards have different activation and completion mechanics. Ambiguous IDs and a single vague lifecycle convention cause collisions, duplicate completion, leaked observers, and unsafe concurrent routing.

## Decision

Public BoardID raw values use `pub.mod.<Module>.<Board>` with no `IO` suffix. Every Board follows the lifecycle contract of its declared type. Common lifecycle code completes at most once and only after owned streams and observers are released. Viewless boards keep Board and controller lifetimes distinct and use explicit attachment context. BlockTask boards complete each activation exactly once through the task completion contract and do not call Board `complete()`.

## Consequences

- Board identity is stable across target naming changes.
- Common and type-specific lifecycle obligations are independently visible.
- Re-activation and concurrent BlockTask behavior have explicit safety boundaries.

## Alternatives considered

- Embedding `IO` in public BoardID values was rejected because target naming is not domain identity.
- Folding viewless and BlockTask behavior into one generic lifecycle rule was rejected because their ownership and completion mechanics differ materially.

## Migration

Rename nonconforming public IDs, identify every Board type, remove duplicate completion paths, and migrate viewless and BlockTask implementations to their type-specific contracts.

## Canon mapping

- Rules: `BRD-ID-001`, `BRD-LIFE-001`, `BRD-VIEWLESS-001`, `BRD-BLOCKTASK-001`
- Profiles: `boardy-vip`
- Reference: `standards/specs/MICROBOARD_NONUI.md`
- Migration: `MIG-ADR-0004`
