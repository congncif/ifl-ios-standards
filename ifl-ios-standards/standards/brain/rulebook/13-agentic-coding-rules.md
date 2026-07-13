<!-- Created by claude-sonnet-4-6 on 2026-05-18 -->
<!-- brain-version: 1.0.0 · last-updated: 2026-05-18 -->

# 13. Agentic Coding Rules

### 13.1 Design for Local Reasoning

Agents have limited context. The codebase must be navigable with **minimum upstream knowledge**:

- A file should be understandable knowing only its imports
- A function should be understandable knowing only its parameters and return type
- A module should be understandable knowing only its interface module
- A change should be defensible knowing only the surrounding 100 lines

### 13.2 Deterministic Structure

Agents perform better when structure is predictable:

- **One module = one folder** with a canonical layout
- **One screen = one folder** containing all its presentation files
- **Naming patterns** are mechanically derivable (`{Feature}Repository`, `{Action}UseCase`)
- **File locations** are derivable from concept (`Infrastructure/Network/` for HTTP adapters)

### 13.3 Explicit Contracts

Agents follow contracts more reliably than convention:

- Interface modules state what is exported
- Protocol declarations state what is implemented
- Composition roots state what is wired
- Tests state what is observable

Implicit conventions ("we usually put X in Y") are agent-hostile.

### 13.4 Safe Refactoring Boundaries

When an agent refactors:

- Stay **within one module** unless the task explicitly requires cross-module changes
- Stay **within one layer** unless the task explicitly requires cross-layer changes
- Preserve all **public** signatures unless the task explicitly changes the contract
- Match existing **naming, formatting, and access modifiers** exactly

### 13.5 Multi-Agent Collaboration Patterns

| Agent role | Responsibility | Forbidden actions |
|------------|---------------|-------------------|
| **Planner** | Decompose tasks, produce phased plan | Editing source code |
| **Architect** | Define interfaces and module boundaries | Implementing internals |
| **Implementer** | Write code matching the defined contract | Changing interfaces without architect approval |
| **Reviewer** | Verify architecture compliance and quality | Editing the code under review |
| **Tester** | Write tests for defined behaviors | Modifying production code to make tests pass |

Each agent reads the rulebook. Each agent reports concrete results, not summaries of intent.

### 13.6 Agentic Discipline Rules

1. **Read before write.** Always inspect the file being changed before editing.
2. **Smallest correct change.** Do not "improve" surrounding code.
3. **No speculative features.** Build what is asked, no more.
4. **No premature abstraction.** Concrete code first; abstract only when the second use case arrives.
5. **No unrelated cleanup.** A bug fix does not include reformatting.
6. **No silent decisions.** Surface tradeoffs; do not pick the controversial path quietly.
7. **No bypass of applicable safety checks.** Never disable hooks, omit a required executable signal,
   or force-push as a shortcut.
8. **Verify proportionally.** For executable changes, observe the smallest risk-relevant build, test,
   or runtime signal. Documentation-only changes require no build/test gate.
9. **Report facts.** Changed files, commands run, exit codes observed, what remains.
10. **Stop and ask** when ambiguity could materially affect the design.

### 13.7 Agent Self-Review Before Reporting Completion

Before claiming "done":

- [ ] Executable changes have the smallest risk-relevant signal required by the consuming repository
- [ ] Documentation-only changes did not trigger a build/test loop
- [ ] Diff is reviewed line by line for unrelated changes
- [ ] No layer or dependency violations introduced
- [ ] No new public surface added without justification
- [ ] No third-party dependencies added without justification
- [ ] No vendor types in contract modules
- [ ] Trace headers / authorship metadata present on new files (per project convention)
- [ ] The change is the **minimum correct change**

Task self-review is not an architecture-review checkpoint. Complete the approved plan, then run its
one final joined AI consistency review over the whole candidate.

---
