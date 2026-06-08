<!-- Created by claude-opus-4-7 on 2026-05-09 -->
# EXAMPLES: IO Layer

All 4 files for one public board's IO interface.
Placeholders: `{Module}` = module name, `{Name}` = board name.

---

```swift
// IO/{Module}ServiceMap.swift
public final class {Module}ServiceMap: ServiceMap {}
public extension ServiceMap {
    var mod{Module}: {Module}ServiceMap { link() }
}
```

```swift
// IO/{Name}/{Name}IOInterface.swift
import Boardy
import Foundation

public extension BoardID {
    static let pub{Name}: BoardID = "pub.mod.{Module}.{Name}"
}

public typealias {Name}MainDestination = MainboardGenericDestination<
    {Name}Input, {Name}Output, {Name}Command, {Name}Action
>

extension MotherboardType where Self: FlowManageable {
    func io{Name}(_ id: BoardID = .pub{Name}) -> {Name}MainDestination {
        {Name}MainDestination(destinationID: id, mainboard: self)
    }
}
```

```swift
// IO/{Name}/{Name}InOut.swift
import Boardy
import Foundation
import UIKit

public struct {Name}Input {
    public weak var context: UIViewController?
    public let completion: (() -> Void)?
    public init(context: UIViewController? = nil, completion: (() -> Void)? = nil) {
        self.context = context
        self.completion = completion
    }
}

public typealias {Name}Parameter = BlockTaskParameter<{Name}Input, {Name}Output>

public enum {Name}Output {
    case completed
    case cancelled
}

public typealias {Name}Command = Void   // or enum {Name}Command { case refresh }
public enum {Name}Action: BoardFlowAction {}
```

```swift
// IO/{Name}/ServiceMap+{Name}.swift
import Boardy
import Foundation

public extension {Module}ServiceMap {
    var io{Name}: {Name}MainDestination { mainboard.io{Name}() }
}
```
