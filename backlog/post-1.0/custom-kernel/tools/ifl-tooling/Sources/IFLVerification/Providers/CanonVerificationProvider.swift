import Foundation
import IFLCanon
import IFLContracts

public struct CanonVerificationProvider: Sendable {
    private let source: CanonVerificationSource
    private let readEventHandler: CanonRepositoryReadEventHandler

    public init(canonRoot: URL) {
        source = .url(canonRoot)
        readEventHandler = { _ in }
    }

    package init(resolvedRoot: ResolvedVerificationRoot) {
        source = .resolved(resolvedRoot)
        readEventHandler = { _ in }
    }

    package init(
        resolvedRoot: ResolvedVerificationRoot,
        readEventHandler: @escaping CanonRepositoryReadEventHandler
    ) {
        source = .resolved(resolvedRoot)
        self.readEventHandler = readEventHandler
    }

    public func checks(
        profiles: Set<String>,
        requirements: Set<String>
    ) throws -> [CheckResult] {
        let resolvedRoot = try resolvedRoot()
        try resolvedRoot.validateBinding()
        let repository = FileCanonRepository(
            anchor: resolvedRoot.canonAnchor,
            readEventHandler: readEventHandler
        )
        let completeSnapshot: CanonSnapshot
        do {
            completeSnapshot = try repository.snapshot(profiles: [])
        } catch {
            let snapshotError = error
            try resolvedRoot.validateBinding()
            throw snapshotError
        }
        try resolvedRoot.validateBinding()

        let availableProfiles = Set(completeSnapshot.profiles.map(\.id.rawValue))
        let availableRequirements = Set(
            completeSnapshot.requirementRegistry.requirements.map(\.id.rawValue)
        )
        let unknownProfiles = profiles.subtracting(availableProfiles).sorted(by: canonicalLess)
        let unknownRequirements = requirements
            .subtracting(availableRequirements)
            .sorted(by: canonicalLess)
        if !unknownProfiles.isEmpty || !unknownRequirements.isEmpty {
            return [filterFailure(
                unknownProfiles: unknownProfiles,
                unknownRequirements: unknownRequirements
            )]
        }

        let requestedProfiles = Set(profiles.map(ProfileID.init(rawValue:)))
        let selectedSnapshot = try completeSnapshot.selectingProfiles(requestedProfiles)
        let findings = CanonValidator().validate(selectedSnapshot)
        guard !findings.isEmpty else {
            return [CheckResult(checkID: "CHK-CAN-VALIDATE-001", passed: true)]
        }
        return findings.map { finding in
            let evidence = finding.evidenceReferences.sorted(by: canonicalLess)
            let suffix = evidence.isEmpty
                ? ""
                : " Evidence: \(evidence.joined(separator: ", "))."
            return CheckResult(
                checkID: finding.checkID,
                passed: false,
                severity: finding.severity,
                message: finding.message + suffix
            )
        }
    }

    public func report(
        profiles: Set<String>,
        requirements: Set<String>
    ) -> VerificationReport {
        do {
            let checks = try checks(profiles: profiles, requirements: requirements)
            let exitCode: IFLExitCode = if checks.contains(where: {
                $0.checkID == "CHK-CAN-FILTER-001"
            }) {
                .invalidInput
            } else if checks.contains(where: { !$0.passed }) {
                .conformanceFailure
            } else {
                .passed
            }
            return VerificationReport(exitCode: exitCode, checks: checks)
        } catch {
            return VerificationReport(
                exitCode: canonVerificationExitCode(for: error),
                checks: [CheckResult(
                    checkID: "CHK-CAN-LOAD-001",
                    passed: false,
                    message: String(describing: error)
                )]
            )
        }
    }

    private func resolvedRoot() throws -> ResolvedVerificationRoot {
        switch source {
        case let .url(canonRoot):
            try VerificationRootLocator().resolveAnchored(
                root: URL?.none,
                canonRoot: canonRoot
            )
        case let .resolved(resolvedRoot):
            resolvedRoot
        }
    }

    private func filterFailure(
        unknownProfiles: [String],
        unknownRequirements: [String]
    ) -> CheckResult {
        var components: [String] = []
        if !unknownProfiles.isEmpty {
            components.append("Unknown Profile selector(s): \(unknownProfiles.joined(separator: ", "))")
        }
        if !unknownRequirements.isEmpty {
            components.append(
                "Unknown Requirement selector(s): \(unknownRequirements.joined(separator: ", "))"
            )
        }
        return CheckResult(
            checkID: "CHK-CAN-FILTER-001",
            passed: false,
            severity: .high,
            message: components.joined(separator: ". ") + "."
        )
    }

    private func canonicalLess(_ lhs: String, _ rhs: String) -> Bool {
        lhs.utf8.lexicographicallyPrecedes(rhs.utf8)
    }
}

package func canonVerificationExitCode(for error: any Error) -> IFLExitCode {
    if let error = error as? VerificationRootError {
        return error.exitCode
    }
    if error is CanonDescriptorFailure {
        return .integrityViolation
    }
    guard let error = error as? ContractError else {
        return .internalError
    }
    switch error {
    case .digestMismatch:
        return .integrityViolation
    case let .unresolvedReference(kind, _) where kind == "canon file":
        return .blockedEnvironment
    default:
        return .invalidInput
    }
}

private enum CanonVerificationSource {
    case url(URL)
    case resolved(ResolvedVerificationRoot)
}
