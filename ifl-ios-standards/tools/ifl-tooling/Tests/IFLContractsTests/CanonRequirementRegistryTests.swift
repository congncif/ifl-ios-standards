import Foundation
@testable import IFLContracts
import Testing

extension CanonRegistryFileTests {
    @Test("production requirement registry is the exact approved canonical bootstrap")
    func requirementRegistryBootstrap() throws {
        let data = try registryData("requirements.v1.json")
        let registry = try CanonicalJSON.decode(RequirementRegistry.self, from: data)

        #expect(registry.schemaVersion == 1)
        #expect(registry.requirements.map(\.id.rawValue) == Self.approvedRequirementIDs)
        #expect(registry.requirements.allSatisfy { $0.status == .planned })
        #expect(
            Dictionary(uniqueKeysWithValues: registry.requirements.map {
                ($0.id.rawValue, $0.accountableOwnerRoleID)
            }) == Self.approvedRequirementOwners
        )

        #expect(registry.traceability.map(\.requirementID.rawValue) == ["REQ-CONVERGENCE"])
        let convergence = try #require(registry.traceability.first)
        #expect(convergence.accountableOwnerRoleID == "Workflow Maintainer")
        #expect(convergence.ruleBindings.isEmpty)
        #expect(convergence.internalCheckNamespace == "CHK-WF-CONV-*")
        #expect(convergence.internalCheckIDs == Self.internalConvergenceChecks)
        #expect(convergence.publicCheckIDs == Self.publicConvergenceChecks)
        #expect(convergence.allCheckIDs.count == 13)
        #expect(convergence.fixtureNamespace == "FIX-WF-CONV-*")
        #expect(convergence.fixtureMappings.count == 13)
        #expect(convergence.fixtureMappings.map(\.checkID) == Self.allConvergenceChecks)
        for mapping in convergence.fixtureMappings {
            let stem = mapping.checkID
                .replacingOccurrences(of: "CHK-WF-CONV-", with: "")
                .replacingOccurrences(of: "CHK-", with: "")
            #expect(mapping.positiveFixtureIDs == ["FIX-WF-CONV-\(stem)-PASS"])
            #expect(mapping.negativeFixtureIDs == ["FIX-WF-CONV-\(stem)-FAIL-001"])
        }
        #expect(convergence.requiredEvidenceKinds == [
            "review_confirmation_receipt/v1",
            "review_convergence_receipt/v1",
        ])

        let canonicalData = try canonicalFileData(registry)
        #expect(data == canonicalData)
        let object = try JSONSerialization.jsonObject(with: data)
        let keys = recursiveKeys(in: object)
        #expect(keys.isDisjoint(with: Self.forbiddenWorkflowKeys))
    }
}
