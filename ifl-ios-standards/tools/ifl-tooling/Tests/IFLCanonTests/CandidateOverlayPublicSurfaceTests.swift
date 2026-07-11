import Foundation
@testable import IFLCanon
import Testing

@Suite("CandidateOverlayPublicSurfaceTests", .serialized)
struct CandidateOverlayPublicSurfaceTests {
    @Test("the validated token is immutable Sendable state, not a Codable wire contract")
    func immutableSendableNonCodableToken() throws {
        try CandidateOverlayFixture.withValidFixture { fixture in
            let token = try fixture.validate()
            assertSendable(token)

            #expect(!(ValidatedCandidateOverlay.self is any Encodable.Type))
            #expect(!(ValidatedCandidateOverlay.self is any Decodable.Type))
            #expect(Mirror(reflecting: token).displayStyle == .struct)
        }
    }

    @Test("the public token source declares no forgeable initializer or raw source seam")
    func noPublicConstructionOrRawSourceSeam() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/IFLCanon/ValidatedCandidateOverlay.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        #expect(source.contains("public struct ValidatedCandidateOverlay: Sendable"))
        #expect(!source.contains("public init"))
        #expect(!source.contains("package init"))
        #expect(!source.contains("public var"))
        #expect(!source.contains("Codable"))
        #expect(!source.contains("Encodable"))
        #expect(!source.contains("Decodable"))
        #expect(!source.contains("CandidateOverlayArtifactSource"))
        #expect(!source.contains("URL"))
    }

    @Test("validation is the sole package path that returns a token")
    func validatorMintsOnlyAfterCompleteValidation() throws {
        try CandidateOverlayFixture.withValidFixture { fixture in
            let validator = CandidateOverlayValidator(anchor: fixture.anchor)
            let token: ValidatedCandidateOverlay = try validator.validate(
                overlayID: fixture.overlayID,
                base: fixture.baseSnapshot
            )

            #expect(token.overlayID == fixture.overlayID)
        }
    }

    @Test("retained evidence construction and sibling identity remain module-internal")
    func evidenceAndAnchorConstructionSurface() throws {
        let sourceRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/IFLCanon")
        let snapshotSource = try String(
            contentsOf: sourceRoot.appendingPathComponent("CanonSnapshot.swift"),
            encoding: .utf8
        )
        let anchorSource = try String(
            contentsOf: sourceRoot.appendingPathComponent("RetainedPluginRootAnchor.swift"),
            encoding: .utf8
        )
        let readerSource = try String(
            contentsOf: sourceRoot.appendingPathComponent("CanonDescriptorReader.swift"),
            encoding: .utf8
        )

        #expect(!snapshotSource.contains("package init("))
        #expect(anchorSource.contains("standardsAnchor"))
        #expect(anchorSource.contains("activeCanonAnchor"))
        #expect(readerSource.contains("visitedDirectoryIdentities"))
    }
}

private func assertSendable(_ value: some Sendable) {
    _ = value
}
