<!-- Created by claude-opus-4-7 on 2026-05-09 -->
# EXAMPLES -- Pattern Dictionary Index

Load the file for the work unit you need. Each file is self-contained.
Do NOT load multiple example files at once -- pick the one that matches your task.

| Work Unit | File | Contents |
|-----------|------|---------|
| IO layer (public interface) | `EXAMPLES_IO.md` | ServiceMap (IO) + IOInterface + InOut + ServiceMap ext |
| Plugin layer | `EXAMPLES_PLUGIN.md` | ServiceMap (internal) + ModulePlugin + LauncherPlugin + internal BoardID |
| Full VIP UI Board | `EXAMPLES_VIP_BOARD.md` | Protocols + Board + Interactor + Presenter + ViewController + Builder |
| Viewless Board | `EXAMPLES_VIEWLESS_BOARD.md` | Protocols + Controller + Builder + Board (no UI, has business logic) |
| Non-UI boards | `EXAMPLES_NONUI_BOARDS.md` | Flow Board + BlockTask Board |
| Service layer | `EXAMPLES_SERVICE.md` | UseCase + Repository + Domain model + REST service |

## When to load examples vs specs

- **Examples**: concrete code skeletons, load when implementing (writing code)
- **Specs** (`MICROBOARD_UI.md`, `VIP_COMPONENTS.md`, etc. in this plugin's `standards/specs/`):
  rules + detailed explanations, load when uncertain about architecture decisions
- For standard implementation tasks, load this plugin's `standards/rules/QUICK_REF.md` plus the one
  matching example; read project-specific paths and commands from the consuming repository's root
  `CLAUDE.md` or `AGENTS.md`
