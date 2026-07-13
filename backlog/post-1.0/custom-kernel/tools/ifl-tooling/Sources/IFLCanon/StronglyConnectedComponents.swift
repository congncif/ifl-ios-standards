enum StronglyConnectedComponents {
    static func cyclicComponents<Node: Hashable>(
        nodes: [Node],
        successors: (Node) -> [Node]
    ) -> [[Node]] {
        let knownNodes = Set(nodes)
        var adjacency: [Node: [Node]] = [:]
        var reverseAdjacency: [Node: [Node]] = [:]
        adjacency.reserveCapacity(nodes.count)
        reverseAdjacency.reserveCapacity(nodes.count)

        for node in nodes {
            let targets = successors(node).filter(knownNodes.contains)
            adjacency[node] = targets
            if reverseAdjacency[node] == nil {
                reverseAdjacency[node] = []
            }
            for target in targets {
                reverseAdjacency[target, default: []].append(node)
            }
        }

        var visited = Set<Node>()
        var finishOrder: [Node] = []
        finishOrder.reserveCapacity(nodes.count)
        for start in nodes where !visited.contains(start) {
            var stack: [(node: Node, expanded: Bool)] = [(start, false)]
            while let frame = stack.popLast() {
                if frame.expanded {
                    finishOrder.append(frame.node)
                    continue
                }
                guard visited.insert(frame.node).inserted else { continue }
                stack.append((frame.node, true))
                for target in adjacency[frame.node] ?? [] where !visited.contains(target) {
                    stack.append((target, false))
                }
            }
        }

        var assigned = Set<Node>()
        var cyclicComponents: [[Node]] = []
        for start in finishOrder.reversed() where assigned.insert(start).inserted {
            var component: [Node] = []
            var stack = [start]
            while let node = stack.popLast() {
                component.append(node)
                for predecessor in reverseAdjacency[node] ?? []
                    where assigned.insert(predecessor).inserted
                {
                    stack.append(predecessor)
                }
            }

            if component.count > 1
                || adjacency[component[0]]?.contains(component[0]) == true
            {
                cyclicComponents.append(component)
            }
        }
        return cyclicComponents
    }
}
