struct NamespaceProjection {
    let identityKind: String
    let id: String
    let expectedPattern: String
    let expectedStewardRoleID: String
}

struct StrictNamespaceRegistry: Codable, Equatable {
    let schemaVersion: Int
    let resolutionPolicy: String
    let allocations: [StrictNamespaceAllocation]

    init(from decoder: any Decoder) throws {
        try rejectAdditionalKeys(
            from: decoder,
            allowed: Set(CodingKeys.allCases.map(\.rawValue))
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        resolutionPolicy = try container.decode(String.self, forKey: .resolutionPolicy)
        allocations = try container.decode([StrictNamespaceAllocation].self, forKey: .allocations)
    }

    func mostSpecificAllocations(for projection: NamespaceProjection) -> [StrictNamespaceAllocation] {
        let matching = allocations.compactMap { allocation -> (StrictNamespaceAllocation, Int)? in
            guard allocation.identityKind == projection.identityKind,
                  let specificity = allocation.matchSpecificity(for: projection.id)
            else { return nil }
            return (allocation, specificity)
        }
        guard let maximumSpecificity = matching.map(\.1).max() else { return [] }
        return matching
            .filter { $0.1 == maximumSpecificity }
            .map(\.0)
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion = "schema_version"
        case resolutionPolicy = "resolution_policy"
        case allocations
    }
}

struct StrictNamespaceAllocation: Codable, Equatable {
    let identityKind: String
    let pattern: String
    let stewardRoleID: String

    init(
        identityKind: String,
        pattern: String,
        stewardRoleID: String
    ) {
        self.identityKind = identityKind
        self.pattern = pattern
        self.stewardRoleID = stewardRoleID
    }

    init(from decoder: any Decoder) throws {
        try rejectAdditionalKeys(
            from: decoder,
            allowed: Set(CodingKeys.allCases.map(\.rawValue))
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        identityKind = try container.decode(String.self, forKey: .identityKind)
        pattern = try container.decode(String.self, forKey: .pattern)
        stewardRoleID = try container.decode(String.self, forKey: .stewardRoleID)
    }

    func matchSpecificity(for id: String) -> Int? {
        if pattern.hasSuffix("*") {
            let prefix = String(pattern.dropLast())
            return id.hasPrefix(prefix) ? prefix.utf8.count : nil
        }
        return id == pattern ? pattern.utf8.count : nil
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case identityKind = "identifier_kind"
        case pattern
        case stewardRoleID = "steward_role_id"
    }
}
