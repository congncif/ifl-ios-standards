<!-- Created by claude-sonnet-4-6 on 2026-05-18 -->
<!-- brain-version: 1.0.0 · last-updated: 2026-05-18 -->

# 16. Naming & Organization Rules

### 16.1 Naming Heuristics

- **Business names** for business concepts (`Order`, not `OrderEntity`)
- **Pattern names** for technical concepts (`OrderRepository`, `OrderRepositoryAdapter`)
- **Verb-first** for actions (`submitOrder`, `loadProfile`)
- **No type-name suffixes** on value types (`Order`, not `OrderStruct`)
- **No abbreviations** except universally recognized ones (`URL`, `ID`, `HTTP`)

### 16.2 Naming Convention Stability

The agent ecosystem depends on names being **mechanically derivable**:

| Concept | Pattern |
|---------|---------|
| Domain entity | `{Name}` |
| Domain error | `{Feature}Error` |
| Repository protocol | `{Entity}Repository` |
| Use case protocol | `{Action}UseCase` |
| Use case implementation | `{Action}UseCaseImpl` |
| Infrastructure adapter | `{Tech}{Entity}Repository` (e.g., `RESTUserRepository`) |
| DTO | `{Entity}DTO` |
| View model | `{Screen}ViewModel` |
| View | `{Screen}View` |

Choose one set of patterns per project. Document them once. Apply mechanically.

### 16.3 File Organization

- **One primary type per file.** Helpers stay in the same file when they exist only to support the primary type.
- **File name matches primary type name.**
- **Grouping by concept, not by file type.** A feature folder contains its model, view, business, and infrastructure files — not separate `Models/`, `Views/`, `Controllers/` folders sliced across features.
- **Vertical slice ownership.** Each feature is self-contained; cross-feature concepts live in shared modules.

### 16.4 Folder Predictability

Within a module that adopts this skeleton, an agent should be able to predict where any file lives from its concept alone:

| Concept | Folder |
|---------|--------|
| Domain model | `Sources/Domain/Models/` |
| Repository protocol | `Sources/Domain/Repositories/` |
| Use case | `Sources/BusinessApplication/UseCases/` |
| Presentation files | `Sources/Presentation/{Screen}/` |
| Network adapter | `Sources/Infrastructure/Network/` |
| Persistence adapter | `Sources/Infrastructure/Persistence/` |
| Composition root | `Sources/Composition/` |

---

