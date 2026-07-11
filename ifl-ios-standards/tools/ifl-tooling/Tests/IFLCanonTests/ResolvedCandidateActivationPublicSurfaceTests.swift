import Foundation
@testable import IFLCanon
import Testing

@Suite("ResolvedCandidateActivationPublicSurfaceTests", .serialized)
struct ResolvedCandidateActivationPublicSurfaceTests {
    @Test("the resolved token is immutable Sendable state, not a Codable wire contract")
    func immutableSendableNonCodableToken() throws {
        try ResolverCandidateFixture.withResolvableFixture { fixture in
            let candidate = try fixture.validate()
            let token = try CandidateOverlayResolver().resolve(
                candidate,
                approval: ResolverCandidateFixture.approval(
                    for: candidate,
                    timestamp: ResolverCandidateFixture.approvalTimestamp
                )
            )
            assertResolvedSendable(token)

            #expect(!(ResolvedCandidateActivation.self is any Encodable.Type))
            #expect(!(ResolvedCandidateActivation.self is any Decodable.Type))
            #expect(Mirror(reflecting: token).displayStyle == .struct)
            #expect(!token.outputFiles.isEmpty)
            #expect(!token.outputDirectories.isEmpty)
            #expect(!token.digestTransitions.isEmpty)
            #expect(token.approvalInput.approvalSidecarBytes.count > 0)
            #expect(token.candidateTreeCapture.filesByRelativePath.count > 0)
            #expect(token.basePluginInventory.entries.count > 0)
            #expect(token.resolvedPluginInventory.entries.count > 0)
        }
    }

    @Test("the public type has no construction, mutation, alias, Codable, or raw-source seam")
    func noForgeablePublicSurface() throws {
        let sourceRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/IFLCanon")
        let sourceURLs = try #require(FileManager.default.enumerator(
            at: sourceRoot,
            includingPropertiesForKeys: nil
        )).compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
        let sources = try Dictionary(uniqueKeysWithValues: sourceURLs.map { url in
            try (
                url.lastPathComponent,
                String(contentsOf: url, encoding: .utf8)
            )
        })
        let resolvedSource = try #require(sources["ResolvedCandidateActivation.swift"])
        let resolverSource = try #require(sources["CandidateOverlayResolver.swift"])
        let transformSource = try #require(sources["CandidateActivationTransform.swift"])
        let completeSurface = sources.values.joined(separator: "\n")

        #expect(resolvedSource.contains("public struct ResolvedCandidateActivation: Sendable"))
        #expect(!resolvedSource.contains("public init"))
        #expect(!resolvedSource.contains("package init"))
        #expect(!resolvedSource.contains("public var"))
        #expect(!resolvedSource.contains("package var"))
        #expect(!resolvedSource.contains("mutating func"))
        #expect(!resolvedSource.contains(" set {"))
        #expect(!resolvedSource.contains("didSet"))
        #expect(!resolvedSource.contains("willSet"))
        #expect(!resolvedSource.contains("typealias"))
        #expect(!resolvedSource.contains("static func"))
        #expect(!resolvedSource.contains("class func"))
        #expect(!resolvedSource.contains("Codable"))
        #expect(!resolvedSource.contains("Encodable"))
        #expect(!resolvedSource.contains("Decodable"))
        #expect(resolverSource.contains("package func resolve("))
        #expect(!resolverSource.contains("public func"))
        #expect(!resolverSource.contains("public var"))
        #expect(!transformSource.contains("ResolvedCandidateActivation"))

        let returningSources = sources.filter {
            $0.value.contains("-> ResolvedCandidateActivation")
        }
        #expect(returningSources.keys.sorted() == ["CandidateOverlayResolver.swift"])
        #expect(
            completeSurface.components(separatedBy: "-> ResolvedCandidateActivation").count
                == 2
        )
        #expect(
            completeSurface.components(separatedBy: "ResolvedCandidateActivation(").count
                == 2
        )
        #expect(!completeSurface.contains("typealias ResolvedCandidateActivation"))
        #expect(!completeSurface.contains("extension ResolvedCandidateActivation"))

        for source in [resolvedSource, resolverSource, transformSource] {
            #expect(!source.contains(" set {"))
            #expect(!source.contains("didSet"))
            #expect(!source.contains("willSet"))
            #expect(!source.contains("CandidateOverlayArtifactSource"))
            #expect(!source.contains("FileManager"))
            #expect(!source.contains("ProcessInfo"))
            #expect(!source.contains("getenv"))
            #expect(!source.contains("Date()"))
            #expect(!source.contains("URL"))
            #expect(!source.contains("Authorization"))
            #expect(!source.contains("Lease"))
            #expect(!source.contains("Writer"))
        }
    }

    @Test("resolution is the sole package callable that returns the protected token")
    func resolverIsSoleConstructionPath() throws {
        let sourceRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/IFLCanon")
        let sourceURLs = try #require(FileManager.default.enumerator(
            at: sourceRoot,
            includingPropertiesForKeys: nil
        )).compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
        let completeSurface = try sourceURLs.map {
            try String(contentsOf: $0, encoding: .utf8)
        }.joined(separator: "\n")

        #expect(
            completeSurface.components(separatedBy: "-> ResolvedCandidateActivation").count
                == 2
        )
        #expect(
            completeSurface.components(separatedBy: "ResolvedCandidateActivation(").count
                == 2
        )
    }
}

private func assertResolvedSendable(_ value: some Sendable) {
    _ = value
}
