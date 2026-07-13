import Foundation
import IFLContracts

package struct CanonSnapshotEvidence {
    package let fullInventory: CanonicalTreeInventory
    package let fullInventoryDigest: HashDigest
    package let projectedInventory: CanonicalTreeInventory
    package let projectedDigest: HashDigest
    package let fileBytesByRelativePath: [String: Data]

    let retainedPluginIdentity: RetainedPluginRootIdentity
    let canonDevice: UInt64
    let canonInode: UInt64
    let snapshotsByRelativePath: [String: CanonFileSnapshot]
}
