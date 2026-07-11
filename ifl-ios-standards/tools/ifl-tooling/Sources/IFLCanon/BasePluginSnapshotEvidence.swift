import IFLContracts

package struct BasePluginSnapshotEvidence {
    package let inventory: CanonicalTreeInventory
    package let inventoryDigest: HashDigest
    package let rootDevice: UInt64
    package let rootInode: UInt64

    let retainedPluginIdentity: RetainedPluginRootIdentity
    let snapshotsByRelativePath: [String: CanonFileSnapshot]

    init(
        inventory: CanonicalTreeInventory,
        snapshotsByRelativePath: [String: CanonFileSnapshot],
        retainedPluginIdentity: RetainedPluginRootIdentity
    ) throws {
        guard let rootSnapshot = snapshotsByRelativePath[""] else {
            throw CanonDescriptorFailure.integrityViolation(
                "base plugin evidence is missing its retained root identity"
            )
        }
        self.inventory = inventory
        inventoryDigest = try CanonicalTreeDigest.digest(inventory)
        rootDevice = rootSnapshot.device
        rootInode = rootSnapshot.inode
        self.retainedPluginIdentity = retainedPluginIdentity
        self.snapshotsByRelativePath = snapshotsByRelativePath
    }
}
