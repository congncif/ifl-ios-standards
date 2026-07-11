import Foundation
import IFLContracts

public struct ArtifactIndependentRoot: Codable, Hashable, Sendable {
    public let schemaVersion: Int
    public let artifactID: ArtifactID
    public let artifactHash: HashDigest

    public init(artifactID: ArtifactID, artifactHash: HashDigest) throws {
        self.artifactID = try ArtifactID(validating: artifactID.rawValue)
        do {
            self.artifactHash = try HashDigest(validating: artifactHash.rawValue)
        } catch {
            throw ArtifactError.invalidDigest
        }
        schemaVersion = 1
    }

    public init(from decoder: any Decoder) throws {
        try artifactRejectUnknownFields(
            from: decoder,
            allowed: Set(CodingKeys.allCases.map(\.rawValue))
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let version = try container.decode(Int.self, forKey: .schemaVersion)
        guard version == 1 else { throw ArtifactError.invalidSchemaVersion(version) }
        try self.init(
            artifactID: container.decode(ArtifactID.self, forKey: .artifactID),
            artifactHash: container.decode(HashDigest.self, forKey: .artifactHash)
        )
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion = "schema_version"
        case artifactID = "artifact_id"
        case artifactHash = "artifact_hash"
    }
}

struct VerifiedArtifactTraceAuthority: Hashable, Sendable {
    let policyID: String
    let policyDigest: HashDigest
    let requiredObligations: [ArtifactDependencyObligation]
    let permittedIndependentRoots: [ArtifactIndependentRoot]

    private init(
        policyID: String,
        policyDigest: HashDigest,
        requiredObligations: [ArtifactDependencyObligation],
        permittedIndependentRoots: [ArtifactIndependentRoot]
    ) throws {
        _ = try ArtifactID(validating: policyID)
        let sortedObligations = requiredObligations.sorted {
            $0.canonicalSortKey < $1.canonicalSortKey
        }
        let sortedRoots = permittedIndependentRoots.sorted { $0.artifactID < $1.artifactID }
        guard Set(sortedObligations).count == sortedObligations.count,
              Set(sortedRoots).count == sortedRoots.count
        else { throw ArtifactError.invalidObligation }
        self.policyID = policyID
        self.policyDigest = try HashDigest(validating: policyDigest.rawValue)
        self.requiredObligations = sortedObligations
        self.permittedIndependentRoots = sortedRoots
    }

    #if DEBUG
    static func testing(
        policyID: String,
        policyDigest: HashDigest,
        requiredObligations: [ArtifactDependencyObligation],
        permittedIndependentRoots: [ArtifactIndependentRoot]
    ) throws -> VerifiedArtifactTraceAuthority {
        try VerifiedArtifactTraceAuthority(
            policyID: policyID,
            policyDigest: policyDigest,
            requiredObligations: requiredObligations,
            permittedIndependentRoots: permittedIndependentRoots
        )
    }
    #endif
}

public struct ArtifactGraph: Encodable, Hashable, Sendable {
    public let schemaVersion: Int
    public let tracePolicyID: String
    public let tracePolicyDigest: HashDigest
    public let artifacts: [ArtifactReference]
    public let dependencies: [ArtifactDependency]
    public let dependencyObligations: [ArtifactDependencyObligation]
    public let independentRoots: [ArtifactIndependentRoot]

    init(
        artifacts: [ArtifactReference],
        dependencies: [ArtifactDependency],
        dependencyObligations: [ArtifactDependencyObligation],
        independentRoots: [ArtifactIndependentRoot],
        authority: VerifiedArtifactTraceAuthority
    ) throws {
        let validatedArtifacts = try artifacts.map { artifact in
            try ArtifactReference(
                id: artifact.id,
                type: artifact.type,
                scope: artifact.scope,
                contentHash: artifact.contentHash
            )
        }
        guard Set(validatedArtifacts.map(\.id)).count == validatedArtifacts.count else {
            throw ArtifactError.duplicateArtifact
        }
        let sortedArtifacts = validatedArtifacts.sorted { $0.id < $1.id }
        let artifactsByID = Dictionary(uniqueKeysWithValues: sortedArtifacts.map { ($0.id, $0) })

        var semanticKeys: Set<ArtifactDependencySemanticKey> = []
        for dependency in dependencies {
            guard semanticKeys.insert(dependency.semanticKey).inserted else {
                throw ArtifactError.duplicateDependency
            }
            guard let upstream = artifactsByID[dependency.upstreamArtifactID],
                  let downstream = artifactsByID[dependency.downstreamArtifactID]
            else { throw ArtifactError.unknownArtifact }
            guard upstream.contentHash == dependency.upstreamHash,
                  downstream.contentHash == dependency.downstreamHash
            else { throw ArtifactError.staleEndpointHash }
            guard dependency.affectedScope.intersects(upstream.scope),
                  dependency.affectedScope.intersects(downstream.scope)
            else { throw ArtifactError.invalidDependency }
        }

        let sortedDependencies = dependencies.sorted { $0.canonicalSortKey < $1.canonicalSortKey }
        let sortedObligations = dependencyObligations.sorted {
            $0.canonicalSortKey < $1.canonicalSortKey
        }
        let expectedObligations = sortedDependencies.map(ArtifactDependencyObligation.init)
        guard sortedObligations == expectedObligations,
              sortedObligations == authority.requiredObligations
        else { throw ArtifactError.invalidObligation }

        try Self.rejectCycles(
            artifactIDs: sortedArtifacts.map(\.id),
            dependencies: sortedDependencies
        )

        let downstreamIDs = Set(sortedDependencies.map(\.downstreamArtifactID))
        let expectedRootIDs = Set(sortedArtifacts.map(\.id)).subtracting(downstreamIDs)
        let sortedRoots = independentRoots.sorted { $0.artifactID < $1.artifactID }
        guard Set(sortedRoots).count == sortedRoots.count,
              Set(sortedRoots.map(\.artifactID)) == expectedRootIDs,
              sortedRoots == authority.permittedIndependentRoots
        else { throw ArtifactError.invalidIndependentRoot }
        for root in sortedRoots {
            guard let artifact = artifactsByID[root.artifactID] else {
                throw ArtifactError.unknownArtifact
            }
            guard artifact.contentHash == root.artifactHash else {
                throw ArtifactError.staleEndpointHash
            }
        }

        schemaVersion = 1
        tracePolicyID = authority.policyID
        tracePolicyDigest = authority.policyDigest
        self.artifacts = sortedArtifacts
        self.dependencies = sortedDependencies
        self.dependencyObligations = sortedObligations
        self.independentRoots = sortedRoots
    }

    public func encode(to encoder: any Encoder) throws {
        try ArtifactGraphWire(graph: self).encode(to: encoder)
    }

    static func decodeCanonical(
        from bytes: Data,
        authority: VerifiedArtifactTraceAuthority?
    ) throws -> ArtifactGraph {
        guard let authority else { throw ArtifactError.invalidObligation }
        let wire = try CanonicalJSON.decode(ArtifactGraphWire.self, from: bytes)
        guard wire.tracePolicyID == authority.policyID,
              wire.tracePolicyDigest == authority.policyDigest
        else { throw ArtifactError.invalidObligation }
        let graph = try ArtifactGraph(
            artifacts: wire.artifacts,
            dependencies: wire.dependencies,
            dependencyObligations: wire.dependencyObligations,
            independentRoots: wire.independentRoots,
            authority: authority
        )
        guard try CanonicalJSON.encode(graph) == bytes else {
            throw ArtifactError.unexpectedFields
        }
        return graph
    }

    func artifact(withID id: ArtifactID) -> ArtifactReference? {
        artifacts.first(where: { $0.id == id })
    }

    func outgoingDependencies(from id: ArtifactID) -> [ArtifactDependency] {
        dependencies.filter { $0.upstreamArtifactID == id }
    }

    func canonicalDigest() throws -> HashDigest {
        CanonicalTreeDigest.sha256(try CanonicalJSON.encode(self))
    }

    private static func rejectCycles(
        artifactIDs: [ArtifactID],
        dependencies: [ArtifactDependency]
    ) throws {
        var indegrees = Dictionary(uniqueKeysWithValues: artifactIDs.map { ($0, 0) })
        var adjacency = Dictionary(uniqueKeysWithValues: artifactIDs.map { ($0, [ArtifactID]()) })
        for dependency in dependencies {
            indegrees[dependency.downstreamArtifactID, default: 0] += 1
            adjacency[dependency.upstreamArtifactID, default: []].append(
                dependency.downstreamArtifactID
            )
        }
        for id in artifactIDs { adjacency[id]?.sort() }

        var queue = artifactIDs.filter { indegrees[$0, default: 0] == 0 }.sorted()
        var visitedCount = 0
        while !queue.isEmpty {
            let current = queue.removeFirst()
            visitedCount += 1
            for downstream in adjacency[current] ?? [] {
                guard let currentIndegree = indegrees[downstream] else {
                    throw ArtifactError.unknownArtifact
                }
                let nextIndegree = currentIndegree - 1
                indegrees[downstream] = nextIndegree
                if nextIndegree == 0 {
                    queue.append(downstream)
                    queue.sort()
                }
            }
        }
        guard visitedCount == artifactIDs.count else { throw ArtifactError.cycle }
    }
}

private struct ArtifactGraphWire: Codable {
    let schemaVersion: Int
    let tracePolicyID: String
    let tracePolicyDigest: HashDigest
    let artifacts: [ArtifactReference]
    let dependencies: [ArtifactDependency]
    let dependencyObligations: [ArtifactDependencyObligation]
    let independentRoots: [ArtifactIndependentRoot]

    init(graph: ArtifactGraph) {
        schemaVersion = graph.schemaVersion
        tracePolicyID = graph.tracePolicyID
        tracePolicyDigest = graph.tracePolicyDigest
        artifacts = graph.artifacts
        dependencies = graph.dependencies
        dependencyObligations = graph.dependencyObligations
        independentRoots = graph.independentRoots
    }

    init(from decoder: any Decoder) throws {
        try artifactRejectUnknownFields(
            from: decoder,
            allowed: Set(CodingKeys.allCases.map(\.rawValue))
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        guard schemaVersion == 1 else {
            throw ArtifactError.invalidSchemaVersion(schemaVersion)
        }
        tracePolicyID = try container.decode(String.self, forKey: .tracePolicyID)
        _ = try ArtifactID(validating: tracePolicyID)
        tracePolicyDigest = try container.decode(HashDigest.self, forKey: .tracePolicyDigest)
        artifacts = try container.decode([ArtifactReference].self, forKey: .artifacts)
        dependencies = try container.decode([ArtifactDependency].self, forKey: .dependencies)
        dependencyObligations = try container.decode(
            [ArtifactDependencyObligation].self,
            forKey: .dependencyObligations
        )
        independentRoots = try container.decode(
            [ArtifactIndependentRoot].self,
            forKey: .independentRoots
        )
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion = "schema_version"
        case tracePolicyID = "trace_policy_id"
        case tracePolicyDigest = "trace_policy_digest"
        case artifacts
        case dependencies
        case dependencyObligations = "dependency_obligations"
        case independentRoots = "independent_roots"
    }
}
