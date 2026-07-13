import IFLContracts

public enum CanonSnapshotContentPolicy {
    public static let currentSchemaVersion = 1
    public static let excludedRoots = ["activations"]

    public static func digest(of fullInventory: CanonicalTreeInventory) throws -> HashDigest {
        try CanonicalTreeDigest.digest(project(fullInventory))
    }

    public static func project(
        _ fullInventory: CanonicalTreeInventory
    ) throws -> CanonicalTreeInventory {
        let projectedEntries = fullInventory.entries.filter { entry in
            !excludedRoots.contains { excludedRoot in
                entry.relativePath == excludedRoot
                    || entry.relativePath.hasPrefix(excludedRoot + "/")
            }
        }
        return try CanonicalTreeInventory(
            policy: CanonicalTreePolicy(excludedRoots: excludedRoots),
            rootMode: fullInventory.rootMode,
            entries: projectedEntries
        )
    }
}
