@testable import IFLCanon
import Testing

@Test("IFLCanon target is available")
func canonTargetIsAvailable() {
    _ = CanonModule.self
}
