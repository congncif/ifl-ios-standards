import IFLContracts

public protocol CanonRepository: Sendable {
    func snapshot(profiles: Set<ProfileID>) throws -> CanonSnapshot
}
