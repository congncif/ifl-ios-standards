import Foundation
@testable import IFLContracts
import Testing

extension CanonRegistryFileTests {
    @Test("namespace registry is strict, canonical, and resolves by longest prefix")
    func namespaceRegistryBootstrap() throws {
        let data = try registryData("namespaces.v1.json")
        let registry = try CanonicalJSON.decode(StrictNamespaceRegistry.self, from: data)

        #expect(registry.schemaVersion == 1)
        #expect(registry.resolutionPolicy == "longest_prefix")
        #expect(registry.allocations == Self.namespaceAllocations)
        let allocationKeys = registry.allocations.map { $0.identityKind + "\u{0}" + $0.pattern }
        #expect(allocationKeys == allocationKeys.sorted())
        let canonicalData = try canonicalFileData(registry)
        #expect(data == canonicalData)

        for allocation in registry.allocations {
            let wildcardCount = allocation.pattern.count(where: { $0 == "*" })
            #expect(wildcardCount == 0 || (wildcardCount == 1 && allocation.pattern.hasSuffix("*")))
            #expect(!allocation.stewardRoleID.isEmpty)
            #expect(
                allocation.stewardRoleID
                    == allocation.stewardRoleID.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
        #expect(Set(allocationKeys).count == allocationKeys.count)

        for projection in Self.namespaceProjections {
            let mostSpecific = registry.mostSpecificAllocations(for: projection)
            #expect(mostSpecific.count == 1, "\(projection.id) must resolve without a longest-prefix tie")
            let resolved = try #require(mostSpecific.first)
            #expect(resolved.pattern == projection.expectedPattern)
            #expect(resolved.stewardRoleID == projection.expectedStewardRoleID)
        }
    }
}
