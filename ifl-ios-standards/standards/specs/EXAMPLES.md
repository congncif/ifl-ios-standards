<!-- Created by claude-opus-4-7 on 2026-05-09 -->
# EXAMPLES -- Pattern Dictionary Index

Load the file for the work unit you need. Each file is self-contained.
Do NOT load multiple example files at once -- pick the one that matches your task.

| Work Unit | File | Contents |
|-----------|------|---------|
| IO layer (public interface) | `.ai/specs/EXAMPLES_IO.md` | ServiceMap (IO) + IOInterface + InOut + ServiceMap ext |
| Plugin layer | `.ai/specs/EXAMPLES_PLUGIN.md` | ServiceMap (internal) + ModulePlugin + LauncherPlugin + internal BoardID |
| Full VIP UI Board | `.ai/specs/EXAMPLES_VIP_BOARD.md` | Protocols + Board + Interactor + Presenter + ViewController + Builder |
| Viewless Board | `.ai/specs/EXAMPLES_VIEWLESS_BOARD.md` | Protocols + Controller + Builder + Board (no UI, has business logic) |
| Non-UI boards | `.ai/specs/EXAMPLES_NONUI_BOARDS.md` | Flow Board + BlockTask Board |
| Service layer | `.ai/specs/EXAMPLES_SERVICE.md` | UseCase + Repository + Domain model + REST service |

## When to load examples vs specs

- **Examples**: concrete code skeletons, load when implementing (writing code)
- **Specs** (`.ai/specs/MICROBOARD_UI.md`, `.ai/specs/VIP_COMPONENTS.md`, etc.): rules + detailed explanations, load when uncertain about architecture decisions
- For standard implementation tasks, loading `.claude/rules/QUICK_REF.md` + the right example file is usually sufficient
