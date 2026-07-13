@testable import IFLVerification
import Testing

@Test("IFLVerification target is available")
func verificationTargetIsAvailable() {
    _ = VerificationReport.self
}
