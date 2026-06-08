<!-- Created by claude-sonnet-4-6 on 2026-05-18 -->
<!-- brain-version: 1.0.0 · last-updated: 2026-05-18 -->

# Appendix A — Generic Module Skeleton

```
{ModuleRoot}/{Module}/
├── {Module}.podspec | Package.swift           # Interface package
├── {Module}Implementation.podspec | ...       # Implementation package
├── Interface/
│   ├── Models/
│   │   └── {Concept}.swift                    # value types
│   ├── Protocols/
│   │   └── {Capability}.swift                 # service contracts
│   └── EntryPoints/
│       └── {Module}EntryPoint.swift           # public registration
└── Sources/
    ├── Domain/
    │   ├── Models/
    │   ├── Repositories/                      # protocols
    │   └── Services/                          # protocols
    ├── BusinessApplication/
    │   ├── UseCases/
    │   ├── Presentation/
    │   └── Coordination/
    ├── Infrastructure/
    │   ├── Network/
    │   ├── Persistence/
    │   ├── Vendor/
    │   └── Tracking/
    └── Composition/
        └── {Module}Composer.swift             # wires concrete types
```

