<!-- Created by claude-sonnet-4-6 on 2026-05-18 -->
<!-- brain-version: 1.0.0 · last-updated: 2026-05-18 -->

# 3. Dependency Rules

### 3.1 Compile-Time Dependency Matrix

| From → To | Allowed? |
|-----------|----------|
| Domain → Foundation | ✅ |
| Domain → Anything else | ❌ |
| Business Application → Domain | ✅ |
| Business Application → UI framework | ❌ (presentation logic excluded — see §9.4) |
| Business Application → Vendor SDK | ❌ except documented architecture primitives |
| Infrastructure → Domain | ✅ |
| Infrastructure → Business Application | ❌ |
| UI → Presentation contracts | ✅ |
| UI → Domain models directly | ❌ — go through a presentation mapping |
| Consumer module → Another module's *contract* | ✅ |
| Consumer module → Another module's *implementation* | ❌ |

### 3.2 Third-Party Decision Order

1. Use Swift / Foundation / UIKit / SwiftUI / Combine / Swift Concurrency / URLSession / Codable / XCTest.
2. Use an existing project-local abstraction.
3. Add a third-party dependency only if SDK is incomplete, risky, or materially more expensive — and isolate it behind an adapter at the Infrastructure layer.

A dependency is acceptable when **all** are true:

- [ ] No reasonable SDK alternative exists
- [ ] No local abstraction already covers it
- [ ] It does not leak into Domain or Business Application layers
- [ ] It is wrapped by an adapter that the rest of the app speaks to via Domain protocols
- [ ] Its public type signatures never appear in contract modules

### 3.3 Dependency Direction Tests

Periodically (and as part of agent self-review):

```
grep -r "import Alamofire"   Domain/   # must return nothing
grep -r "import UIKit"       Domain/   # must return nothing
grep -r "import {VendorSDK}" BusinessApplication/  # must return nothing
```

Any hit indicates a layering violation.

---

