import Foundation
import IFLContracts

struct VerifiedArtifactMutation: Hashable, Sendable {
    let artifactID: ArtifactID
    let storedHash: HashDigest
    let currentHash: HashDigest
    let changedScopes: [ArtifactScope]
    let sectionManifestDigest: HashDigest
    let verifierID: ActorID
    let graphDigest: HashDigest
    let scopeDigest: HashDigest
    let digest: HashDigest
}

enum ArtifactMutationVerifier {
    static func verify(
        graph: ArtifactGraph,
        artifactID: ArtifactID,
        storedBytes: Data,
        currentBytes: Data,
        changedScopes: [ArtifactScope],
        sectionManifestDigest: HashDigest,
        verifierID: ActorID
    ) throws -> VerifiedArtifactMutation {
        guard let artifact = graph.artifact(withID: artifactID) else {
            throw ArtifactError.unknownArtifact
        }
        let storedHash = CanonicalTreeDigest.sha256(storedBytes)
        let currentHash = CanonicalTreeDigest.sha256(currentBytes)
        guard artifact.contentHash == storedHash else {
            throw ArtifactError.staleEndpointHash
        }
        guard storedHash != currentHash else { throw ArtifactError.invalidChange }

        let sortedScopes = changedScopes.sorted { lhs, rhs in
            (lhs.kind.rawValue, lhs.value) < (rhs.kind.rawValue, rhs.value)
        }
        guard !sortedScopes.isEmpty,
              Set(sortedScopes).count == sortedScopes.count,
              sortedScopes.allSatisfy({ $0.intersects(artifact.scope) })
        else { throw ArtifactError.invalidChange }

        let validatedSectionDigest: HashDigest
        let validatedVerifierID: ActorID
        do {
            validatedSectionDigest = try HashDigest(validating: sectionManifestDigest.rawValue)
            validatedVerifierID = try ActorID(validating: verifierID.rawValue)
        } catch {
            throw ArtifactError.invalidChange
        }
        let graphDigest = try graph.canonicalDigest()
        let scopeDigest = CanonicalTreeDigest.sha256(
            try CanonicalJSON.encode(MutationScopeDigestInput(scopes: sortedScopes))
        )
        let digest = CanonicalTreeDigest.sha256(
            try CanonicalJSON.encode(
                MutationDigestInput(
                    artifactID: artifactID,
                    storedHash: storedHash,
                    currentHash: currentHash,
                    graphDigest: graphDigest,
                    sectionManifestDigest: validatedSectionDigest,
                    scopeDigest: scopeDigest,
                    verifierID: validatedVerifierID
                )
            )
        )
        return VerifiedArtifactMutation(
            artifactID: artifactID,
            storedHash: storedHash,
            currentHash: currentHash,
            changedScopes: sortedScopes,
            sectionManifestDigest: validatedSectionDigest,
            verifierID: validatedVerifierID,
            graphDigest: graphDigest,
            scopeDigest: scopeDigest,
            digest: digest
        )
    }
}

enum ArtifactInvalidationProvenance: String, Codable, CaseIterable, Hashable, Sendable {
    case verifiedArtifactMutation = "verified_artifact_mutation"
}

struct ArtifactInvalidationWire: Codable, Hashable, Sendable {
    let schemaVersion: Int
    let graphDigest: HashDigest
    let mutationDigest: HashDigest
    let sectionManifestDigest: HashDigest
    let scopeDigest: HashDigest
    let storedHash: HashDigest
    let currentHash: HashDigest
    let verifierID: ActorID
    let provenance: ArtifactInvalidationProvenance
    let changedArtifactID: ArtifactID
    let staleArtifactIDs: [ArtifactID]

    fileprivate init(
        graphDigest: HashDigest,
        mutationDigest: HashDigest,
        sectionManifestDigest: HashDigest,
        scopeDigest: HashDigest,
        storedHash: HashDigest,
        currentHash: HashDigest,
        verifierID: ActorID,
        changedArtifactID: ArtifactID,
        staleArtifactIDs: [ArtifactID]
    ) throws {
        let sortedStale = staleArtifactIDs.sorted()
        guard !sortedStale.contains(changedArtifactID),
              Set(sortedStale).count == sortedStale.count
        else { throw ArtifactError.invalidInvalidationResult }
        schemaVersion = 1
        self.graphDigest = try HashDigest(validating: graphDigest.rawValue)
        self.mutationDigest = try HashDigest(validating: mutationDigest.rawValue)
        self.sectionManifestDigest = try HashDigest(validating: sectionManifestDigest.rawValue)
        self.scopeDigest = try HashDigest(validating: scopeDigest.rawValue)
        self.storedHash = try HashDigest(validating: storedHash.rawValue)
        self.currentHash = try HashDigest(validating: currentHash.rawValue)
        self.verifierID = try ActorID(validating: verifierID.rawValue)
        provenance = .verifiedArtifactMutation
        self.changedArtifactID = try ArtifactID(validating: changedArtifactID.rawValue)
        self.staleArtifactIDs = sortedStale
    }

    init(from decoder: any Decoder) throws {
        try artifactRejectUnknownFields(
            from: decoder,
            allowed: Set(CodingKeys.allCases.map(\.rawValue))
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let version = try container.decode(Int.self, forKey: .schemaVersion)
        guard version == 1 else { throw ArtifactError.invalidSchemaVersion(version) }
        let provenance = try container.decode(
            ArtifactInvalidationProvenance.self,
            forKey: .provenance
        )
        guard provenance == .verifiedArtifactMutation else {
            throw ArtifactError.invalidInvalidationResult
        }
        let decodedStale = try container.decode([ArtifactID].self, forKey: .staleArtifactIDs)
        let validated = try ArtifactInvalidationWire(
            graphDigest: container.decode(HashDigest.self, forKey: .graphDigest),
            mutationDigest: container.decode(HashDigest.self, forKey: .mutationDigest),
            sectionManifestDigest: container.decode(
                HashDigest.self,
                forKey: .sectionManifestDigest
            ),
            scopeDigest: container.decode(HashDigest.self, forKey: .scopeDigest),
            storedHash: container.decode(HashDigest.self, forKey: .storedHash),
            currentHash: container.decode(HashDigest.self, forKey: .currentHash),
            verifierID: container.decode(ActorID.self, forKey: .verifierID),
            changedArtifactID: container.decode(ArtifactID.self, forKey: .changedArtifactID),
            staleArtifactIDs: decodedStale
        )
        guard decodedStale == validated.staleArtifactIDs else {
            throw ArtifactError.invalidInvalidationResult
        }
        self = validated
    }

    static func decodeCanonical(from bytes: Data) throws -> ArtifactInvalidationWire {
        try artifactDecodeCanonical(ArtifactInvalidationWire.self, from: bytes)
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion = "schema_version"
        case graphDigest = "graph_digest"
        case mutationDigest = "mutation_digest"
        case sectionManifestDigest = "section_manifest_digest"
        case scopeDigest = "scope_digest"
        case storedHash = "stored_hash"
        case currentHash = "current_hash"
        case verifierID = "verifier_id"
        case provenance
        case changedArtifactID = "changed_artifact_id"
        case staleArtifactIDs = "stale_artifact_ids"
    }
}

struct ValidatedArtifactInvalidation: Hashable, Sendable {
    fileprivate let wire: ArtifactInvalidationWire
    let canonicalWireBytes: Data

    var schemaVersion: Int { wire.schemaVersion }
    var graphDigest: HashDigest { wire.graphDigest }
    var mutationDigest: HashDigest { wire.mutationDigest }
    var sectionManifestDigest: HashDigest { wire.sectionManifestDigest }
    var scopeDigest: HashDigest { wire.scopeDigest }
    var storedHash: HashDigest { wire.storedHash }
    var currentHash: HashDigest { wire.currentHash }
    var verifierID: ActorID { wire.verifierID }
    var provenance: ArtifactInvalidationProvenance { wire.provenance }
    var changedArtifactID: ArtifactID { wire.changedArtifactID }
    var staleArtifactIDs: [ArtifactID] { wire.staleArtifactIDs }

    fileprivate init(wire: ArtifactInvalidationWire) throws {
        self.wire = wire
        canonicalWireBytes = try CanonicalJSON.encode(wire)
    }
}

public struct ArtifactInvalidator: Sendable {
    public init() {}

    func invalidate(
        mutation: VerifiedArtifactMutation,
        in graph: ArtifactGraph
    ) throws -> ValidatedArtifactInvalidation {
        let graphDigest = try graph.canonicalDigest()
        guard mutation.graphDigest == graphDigest,
              let artifact = graph.artifact(withID: mutation.artifactID),
              artifact.contentHash == mutation.storedHash
        else { throw ArtifactError.invalidChange }

        let firstHop = graph.outgoingDependencies(from: mutation.artifactID)
            .filter { dependency in
                mutation.changedScopes.contains { dependency.affectedScope.intersects($0) }
            }
            .map(\.downstreamArtifactID)
        var staleIDs = Set(firstHop)
        var frontier = staleIDs.sorted()
        while !frontier.isEmpty {
            let current = frontier.removeFirst()
            let downstreamIDs = graph.outgoingDependencies(from: current)
                .map(\.downstreamArtifactID)
                .sorted()
            for downstreamID in downstreamIDs where staleIDs.insert(downstreamID).inserted {
                frontier.append(downstreamID)
                frontier.sort()
            }
        }

        let wire = try ArtifactInvalidationWire(
            graphDigest: graphDigest,
            mutationDigest: mutation.digest,
            sectionManifestDigest: mutation.sectionManifestDigest,
            scopeDigest: mutation.scopeDigest,
            storedHash: mutation.storedHash,
            currentHash: mutation.currentHash,
            verifierID: mutation.verifierID,
            changedArtifactID: mutation.artifactID,
            staleArtifactIDs: Array(staleIDs)
        )
        return try ValidatedArtifactInvalidation(wire: wire)
    }

    func replay(
        wire: ArtifactInvalidationWire,
        mutation: VerifiedArtifactMutation,
        in graph: ArtifactGraph
    ) throws -> ValidatedArtifactInvalidation {
        let expected = try invalidate(mutation: mutation, in: graph)
        guard wire == expected.wire,
              try CanonicalJSON.encode(wire) == expected.canonicalWireBytes
        else { throw ArtifactError.invalidInvalidationResult }
        return expected
    }
}

private struct MutationScopeDigestInput: Codable {
    let schemaVersion = 1
    let scopes: [ArtifactScope]

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case scopes
    }
}

private struct MutationDigestInput: Codable {
    let schemaVersion = 1
    let artifactID: ArtifactID
    let storedHash: HashDigest
    let currentHash: HashDigest
    let graphDigest: HashDigest
    let sectionManifestDigest: HashDigest
    let scopeDigest: HashDigest
    let verifierID: ActorID

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case artifactID = "artifact_id"
        case storedHash = "stored_hash"
        case currentHash = "current_hash"
        case graphDigest = "graph_digest"
        case sectionManifestDigest = "section_manifest_digest"
        case scopeDigest = "scope_digest"
        case verifierID = "verifier_id"
    }
}
