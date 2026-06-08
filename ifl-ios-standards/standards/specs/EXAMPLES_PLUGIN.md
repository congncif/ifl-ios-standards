<!-- Created by claude-opus-4-7 on 2026-05-09 -->
# EXAMPLES: Plugin Layer

ModuleBuilderPlugin + LauncherPlugin for one module.
Placeholders: `{Module}` = module name, `{Name}` = primary entry board, `{Child}` = internal child board.

---

```swift
// Sources/Plugins/{Module}PluginsServiceMap.swift
import Boardy
import Foundation

final class {Module}PluginsServiceMap: ServiceMap {}   // internal

extension ServiceMap {
    var mod{Module}Plugins: {Module}PluginsServiceMap { link() }
}
```

```swift
// Sources/Plugins/{Module}ModulePlugin.swift
import Boardy
import Foundation
import {Module}

struct {Module}ModulePlugin: ModuleBuilderPlugin {

    enum ServiceType: CaseIterable {
        case `default`
        var identifier: BoardID {
            switch self { case .default: .pub{Name} }
        }
    }

    // Shared deps: stored properties (never created inside closures)
    let sharedRepository: {Entity}Repository = {Entity}MemoryStorageRepository()
    let service: ServiceType
    var identifier: BoardID { service.identifier }

    func build(
        with identifier: BoardID,
        sharedComponent: any SharedValueComponent,
        internalContinuousProducer: any ActivatableBoardProducer
    ) -> any ActivatableBoard {
        // Entry board (coordinator or viewless flow board)
        {Name}Board(identifier: identifier, producer: internalContinuousProducer)
    }

    // Result builder syntax -- no return, no [ ]
    func internalContinuousRegistrations(
        sharedComponent: any SharedValueComponent,
        producer: any ActivatableBoardProducer
    ) -> [BoardRegistration] {
        BoardRegistration(.mod{Child}) { identifier in
            {Child}Board(
                identifier: identifier,
                builder: {Child}Builder(repository: sharedRepository),
                producer: producer
            )
        }
        // Add more BoardRegistration blocks here as needed
    }
}

public struct {Module}LauncherPlugin: LauncherPlugin {
    public init() { /**/ }

    public func prepareForLaunching(withOptions options: MainOptions) -> ModuleComponent {
        ModuleComponent(
            modulePlugins: {Module}ModulePlugin.ServiceType.allCases.map {
                {Module}ModulePlugin(service: $0)
            }
        )
    }
}
```

```swift
// Sources/Microboards/{Child}/{Child}IOInterface.swift  (internal BoardID)
import Boardy
import Foundation

extension BoardID {
    static let mod{Child}: BoardID = "mod.{Module}.{Child}"
}

typealias {Child}MainDestination = MainboardGenericDestination<
    {Child}Input, {Child}Output, {Child}Command, {Child}Action
>

extension MotherboardType where Self: FlowManageable {
    func io{Child}(_ id: BoardID = .mod{Child}) -> {Child}MainDestination {
        {Child}MainDestination(destinationID: id, mainboard: self)
    }
}
```

```swift
// Sources/Microboards/{Child}/ServiceMap+{Child}.swift
import Boardy
import Foundation

extension {Module}PluginsServiceMap {
    var io{Child}: {Child}MainDestination { mainboard.io{Child}() }
}
```
