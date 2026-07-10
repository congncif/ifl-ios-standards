import Foundation
import Testing

extension CanonSchemaFileTests {
    @Test("fixture, derived-artifact, and compatibility-matrix are fully typed contracts")
    func standaloneContractsAreFullyTyped() throws {
        for filename in strictStandaloneSchemas {
            guard let schema = try loadIfPresent(filename) else { continue }
            let problems = contractProblems(in: schema, root: schema, path: "#")
            #expect(problems.isEmpty, "\(filename): \(problems.joined(separator: "; "))")
        }
    }

    @Test("schemas reject nullable, open, unconstrained, and external-reference escape hatches")
    func noSchemaEscapeHatches() throws {
        for expectation in schemaExpectations {
            guard let schema = try loadIfPresent(expectation.filename) else { continue }
            let problems = contractProblems(in: schema, root: schema, path: "#")
            #expect(problems.isEmpty, "\(expectation.filename): \(problems.joined(separator: "; "))")
        }
    }
}

let strictStandaloneSchemas = [
    "fixture.schema.json",
    "derived-artifact.schema.json",
    "compatibility-matrix.schema.json",
]

func contractProblems(
    in schema: [String: Any],
    root: [String: Any],
    path: String
) -> [String] {
    var problems: [String] = []

    if schema["nullable"] != nil {
        problems.append("\(path) uses non-canonical nullable")
    }
    if let types = schema["type"] as? [Any] {
        problems.append("\(path) uses a nullable/union type array \(types)")
    }
    if schema["type"] as? String == "null" || schema["const"] is NSNull {
        problems.append("\(path) permits null")
    }
    if let values = schema["enum"] as? [Any], values.contains(where: { $0 is NSNull }) {
        problems.append("\(path) permits null in enum")
    }

    if let referenceValue = schema["$ref"] {
        guard let reference = referenceValue as? String,
              reference.hasPrefix("#"),
              resolves(reference: reference, in: root)
        else {
            problems.append("\(path) has an external or unresolved $ref")
            return problems
        }
    }

    if schema["patternProperties"] != nil {
        problems.append("\(path) uses patternProperties as an unknown-key escape hatch")
    }
    if let unevaluated = schema["unevaluatedProperties"], unevaluated as? Bool != false {
        problems.append("\(path) leaves unevaluated properties open")
    }

    switch schema["type"] as? String {
    case "object":
        if schema["additionalProperties"] as? Bool != false {
            problems.append("\(path) is not closed with additionalProperties=false")
        }
        guard let properties = schema["properties"] as? [String: Any], !properties.isEmpty else {
            problems.append("\(path) is an unconstrained object leaf")
            break
        }
        guard let required = schema["required"] as? [String] else {
            problems.append("\(path) omits an explicit required list")
            break
        }
        if required.count != Set(required).count {
            problems.append("\(path) repeats a required key")
        }
        if !Set(required).isSubset(of: Set(properties.keys)) {
            problems.append("\(path) requires a key absent from properties")
        }
    case "array":
        let hasTypedItems = (schema["items"] as? [String: Any])?.isEmpty == false
        let hasClosedTuple = (schema["prefixItems"] as? [[String: Any]])?.isEmpty == false
            && schema["items"] as? Bool == false
        guard hasTypedItems || hasClosedTuple else {
            problems.append("\(path) is an unconstrained array leaf")
            break
        }
    case "string":
        let constraintKeys = Set(["const", "enum", "pattern", "format", "minLength", "maxLength"])
        if Set(schema.keys).isDisjoint(with: constraintKeys) {
            problems.append("\(path) is an unconstrained string leaf")
        }
    default:
        break
    }

    for key in ["properties", "$defs", "dependentSchemas"] {
        guard let children = schema[key] as? [String: Any] else { continue }
        for name in children.keys.sorted() {
            if children[name] is Bool {
                continue
            }
            guard let child = children[name] as? [String: Any] else {
                problems.append("\(path)/\(key)/\(name) is not a schema object")
                continue
            }
            problems.append(contentsOf: contractProblems(in: child, root: root, path: "\(path)/\(key)/\(name)"))
        }
    }

    for key in ["items", "contains", "not", "if", "then", "else", "propertyNames"] {
        guard let child = schema[key] as? [String: Any] else { continue }
        problems.append(contentsOf: contractProblems(in: child, root: root, path: "\(path)/\(key)"))
    }

    for key in ["allOf", "anyOf", "oneOf", "prefixItems"] {
        guard let children = schema[key] as? [[String: Any]] else { continue }
        for (index, child) in children.enumerated() {
            problems.append(contentsOf: contractProblems(in: child, root: root, path: "\(path)/\(key)/\(index)"))
        }
    }

    return problems
}

func resolves(reference: String, in root: [String: Any]) -> Bool {
    guard reference == "#" || reference.hasPrefix("#/") else { return false }
    if reference == "#" { return true }

    var current: Any = root
    for rawToken in reference.dropFirst(2).split(separator: "/", omittingEmptySubsequences: false) {
        let token = rawToken.replacingOccurrences(of: "~1", with: "/")
            .replacingOccurrences(of: "~0", with: "~")
        guard let object = current as? [String: Any], let next = object[token] else { return false }
        current = next
    }
    return true
}
