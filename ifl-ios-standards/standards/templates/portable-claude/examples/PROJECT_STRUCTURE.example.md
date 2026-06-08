<!-- Created by claude-sonnet-4-6 on 2026-05-18 -->

# PROJECT_STRUCTURE.example.md — SHAPE REFERENCE

> ⚠️ **DO NOT COPY VALUES.** This file shows the *shape* of a real `PROJECT_STRUCTURE.md`. Fictional modules (`Auth`, `Profile`, `Catalog`, `Cart`, `Settings`, `Payment`, `DesignSystem`) demonstrate a multi-module inventory layout. When SETUP.md generates the real file:
> - List the project's actual modules and schemes (run `xcodebuild -workspace <Workspace> -list` to discover).
> - Filter out third-party CocoaPods schemes (Firebase, gRPC, etc.) — they should not appear in the project-owned scheme inventory.
> - Single-target apps may state "no modules" instead of populating the inventory table.
> - Keep the section order, table columns, and verification commands intact.

---

# PROJECT_STRUCTURE — Project Topology Contract

> **Purpose**: Describe current project topology that changes with code and PRD evolution: schemes, modules, module purposes, and structural inventory.
>
> **Update rule**: update this file in the same change set whenever code, podspecs, Xcode schemes, module boundaries, or PRD scope changes project structure.
>
> **Boundary**: global configuration values live in `<BindingsRoot>/PROJECT_CONFIG.md`; topology/inventory lives here.

---

## 1. Project-Owned Scheme Inventory

This table lists app and local module schemes owned by this repository. `xcodebuild -list` also reports third-party CocoaPods schemes (Firebase, gRPC, etc.) — filter those out; only project-owned schemes belong here.

| Scheme | Purpose | Structure owner |
|--------|---------|-----------------|
| `ExampleApp` | Main app target | App shell |
| `Auth` | Auth interface module | `submodules/Auth/IO/` |
| `AuthPlugins` | Auth implementation module | `submodules/Auth/Sources/` |
| `Profile` | Profile interface module | `submodules/Profile/IO/` |
| `ProfilePlugins` | Profile implementation module | `submodules/Profile/Sources/` |
| `Catalog` | Catalog interface module | `submodules/Catalog/IO/` |
| `CatalogPlugins` | Catalog implementation module | `submodules/Catalog/Sources/` |
| `Cart` | Cart interface module | `submodules/Cart/IO/` |
| `CartPlugins` | Cart implementation module | `submodules/Cart/Sources/` |
| `Payment` | Payment interface module | `submodules/Payment/IO/` |
| `PaymentPlugins` | Payment implementation module | `submodules/Payment/Sources/` |
| `Settings` | Settings interface module | `submodules/Settings/IO/` |
| `SettingsPlugins` | Settings implementation module | `submodules/Settings/Sources/` |
| `DesignSystem` | Shared design system component module (no Plugins target) | `submodules/DesignSystem/Sources/` |

Refresh inventory with:

```bash
xcodebuild -workspace {Workspace} -list
```

---

## 2. Module Inventory

| Module | Role | Interface target | Implementation target |
|--------|------|------------------|------------------------|
| `Auth` | Authentication, session, token storage | `Auth` | `AuthPlugins` |
| `Profile` | User profile, preferences, account settings | `Profile` | `ProfilePlugins` |
| `Catalog` | Product catalog, browse, search, detail | `Catalog` | `CatalogPlugins` |
| `Cart` | Shopping cart, line items, checkout entry | `Cart` | `CartPlugins` |
| `Payment` | Payment methods, transactions, receipts | `Payment` | `PaymentPlugins` |
| `Settings` | App settings, notifications, privacy | `Settings` | `SettingsPlugins` |
| `DesignSystem` | Shared UI components, tokens, styles | `DesignSystem` | *(none — interface-only)* |

> **Single-target alternative**: if the project is not modularized, replace the table with: *"This project is a single-target app. Module inventory is intentionally empty."*

---

## 3. Synchronization Rules

Update this file when any of these change:

- new module added or removed
- module renamed
- module responsibility changes due to PRD scope
- interface/implementation target names change
- Xcode scheme added, removed, or renamed
- shared component target added or removed
- module folder moved
- plugin host topology changes in a way that affects structure

Do not update this file for temporary branches, local experiments, or implementation details that do not change project topology.

---

## 4. Verification Commands

List schemes:

```bash
xcodebuild -workspace {Workspace} -list
```

Check module folders:

```bash
find {ModuleRoot} -maxdepth 2 -name "*.podspec" -print
```

Check interface/implementation split:

```bash
find {ModuleRoot} -maxdepth 3 \( -path "*/IO" -o -path "*/Sources" \) -print
```
