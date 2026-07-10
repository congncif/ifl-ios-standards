@testable import IFLCanon
import Testing

@Suite("StronglyConnectedComponentsTests")
struct StronglyConnectedComponentsTests {
    @Test("a wide diamond DAG remains acyclic without path enumeration")
    func wideDiamondDAG() {
        let levels = 24
        var nodes = ["root"]
        var edges: [String: [String]] = [:]
        var previous = ["root"]
        for level in 0 ..< levels {
            let current = ["left-\(level)", "right-\(level)"]
            nodes.append(contentsOf: current)
            for source in previous {
                edges[source] = current
            }
            previous = current
        }
        nodes.append("sink")
        for source in previous {
            edges[source] = ["sink"]
        }

        let components = StronglyConnectedComponents.cyclicComponents(
            nodes: nodes,
            successors: { edges[$0] ?? [] }
        )

        #expect(components.isEmpty)
    }

    @Test("a dense strongly connected graph produces one component")
    func denseComponent() throws {
        let nodes = Array(0 ..< 128)
        let components = StronglyConnectedComponents.cyclicComponents(
            nodes: nodes,
            successors: { source in nodes.filter { $0 != source } }
        )

        let component = try #require(components.only)
        #expect(Set(component) == Set(nodes))
    }

    @Test("a deep chain is processed iteratively")
    func deepChain() {
        let nodes = Array(0 ..< 50000)
        let components = StronglyConnectedComponents.cyclicComponents(
            nodes: nodes,
            successors: { node in node + 1 < nodes.count ? [node + 1] : [] }
        )

        #expect(components.isEmpty)
    }
}

private extension Collection {
    var only: Element? {
        count == 1 ? first : nil
    }
}
