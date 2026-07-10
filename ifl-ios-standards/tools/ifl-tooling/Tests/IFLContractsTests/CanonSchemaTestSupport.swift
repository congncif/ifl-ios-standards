import Foundation
import Testing

struct NamedSchemaNode {
    let name: String
    let path: String
    let schema: [String: Any]
}

func requiredNames(in schema: [String: Any]) -> [String]? {
    schema["required"] as? [String]
}

func integerValue(_ value: Any?) -> Int? {
    guard let number = value as? NSNumber,
          String(cString: number.objCType) != "c",
          number.doubleValue.rounded(.towardZero) == number.doubleValue
    else { return nil }
    return number.intValue
}

func isInteger(_ value: Any?, equalTo expected: Int) -> Bool {
    integerValue(value) == expected
}

func matches(pattern: String, _ value: String) -> Bool {
    guard let expression = try? NSRegularExpression(pattern: pattern) else { return false }
    let range = NSRange(value.startIndex ..< value.endIndex, in: value)
    return expression.firstMatch(in: value, range: range) != nil
}

func resolvedSchema(_ schema: [String: Any], root: [String: Any]) -> [String: Any]? {
    guard let reference = schema["$ref"] as? String else { return schema }
    return resolve(reference: reference, in: root) as? [String: Any]
}

func resolve(reference: String, in root: [String: Any]) -> Any? {
    guard reference == "#" || reference.hasPrefix("#/") else { return nil }
    if reference == "#" { return root }

    var current: Any = root
    for rawToken in reference.dropFirst(2).split(separator: "/", omittingEmptySubsequences: false) {
        let token = rawToken.replacingOccurrences(of: "~1", with: "/")
            .replacingOccurrences(of: "~0", with: "~")
        guard let object = current as? [String: Any], let next = object[token] else { return nil }
        current = next
    }
    return current
}

func propertySchemas(
    for property: String,
    in schema: [String: Any],
    root: [String: Any],
    visitedReferences: Set<String> = []
) -> [[String: Any]] {
    var results: [[String: Any]] = []

    if let constant = schema["const"] as? [String: Any],
       let value = constant[property]
    {
        results.append(["const": value])
    }
    if let properties = schema["properties"] as? [String: Any],
       let propertySchema = properties[property] as? [String: Any]
    {
        results.append(propertySchema)
    }
    if let reference = schema["$ref"] as? String,
       !visitedReferences.contains(reference),
       let target = resolve(reference: reference, in: root) as? [String: Any]
    {
        results.append(contentsOf: propertySchemas(
            for: property,
            in: target,
            root: root,
            visitedReferences: visitedReferences.union([reference])
        ))
    }
    for keyword in ["allOf", "anyOf", "oneOf"] {
        guard let branches = schema[keyword] as? [[String: Any]] else { continue }
        for branch in branches {
            results.append(contentsOf: propertySchemas(
                for: property,
                in: branch,
                root: root,
                visitedReferences: visitedReferences
            ))
        }
    }
    for keyword in ["if", "then", "else"] {
        guard let branch = schema[keyword] as? [String: Any] else { continue }
        results.append(contentsOf: propertySchemas(
            for: property,
            in: branch,
            root: root,
            visitedReferences: visitedReferences
        ))
    }
    return results
}

func stringConstants(for property: String, in schema: [String: Any], root: [String: Any]) -> [String] {
    let values = propertySchemas(for: property, in: schema, root: root).compactMap { propertySchema -> String? in
        let resolved = resolvedSchema(propertySchema, root: root) ?? propertySchema
        return resolved["const"] as? String
    }
    return Array(Set(values)).sorted()
}

func stringVocabulary(
    for property: String,
    in schema: [String: Any],
    root: [String: Any]
) -> Set<String> {
    propertySchemas(for: property, in: schema, root: root).reduce(into: []) { values, propertySchema in
        let resolved = resolvedSchema(propertySchema, root: root) ?? propertySchema
        if let constant = resolved["const"] as? String {
            values.insert(constant)
        }
        if let alternatives = resolved["enum"] as? [String] {
            values.formUnion(alternatives)
        }
    }
}

func findStringEnum(named name: String, in value: Any) -> [String]? {
    var found: [String] = []

    func visit(_ current: Any) {
        if let object = current as? [String: Any] {
            if let properties = object["properties"] as? [String: Any],
               let property = properties[name] as? [String: Any],
               let values = property["enum"] as? [String]
            {
                found.append(contentsOf: values)
            }
            for child in object.values {
                visit(child)
            }
        } else if let array = current as? [Any] {
            for child in array {
                visit(child)
            }
        }
    }

    visit(value)
    return found.isEmpty ? nil : Array(Set(found)).sorted()
}

func findConditional(
    property: String,
    equals expected: String,
    in schema: [String: Any],
    root: [String: Any]
) -> [String: Any]? {
    if let condition = schema["if"] as? [String: Any],
       stringConstants(for: property, in: condition, root: root) == [expected],
       schema["then"] is [String: Any],
       schema["else"] is [String: Any]
    {
        return schema
    }

    for value in schema.values {
        if let child = value as? [String: Any],
           let found = findConditional(property: property, equals: expected, in: child, root: root)
        {
            return found
        }
        if let children = value as? [[String: Any]] {
            for child in children {
                if let found = findConditional(property: property, equals: expected, in: child, root: root) {
                    return found
                }
            }
        }
    }
    return nil
}

func namedSchemaNodes(in root: [String: Any]) -> [NamedSchemaNode] {
    var nodes: [NamedSchemaNode] = []

    func visit(_ value: Any, name: String, path: String) {
        if let object = value as? [String: Any] {
            nodes.append(.init(name: name, path: path, schema: object))
            for key in object.keys.sorted() {
                if let child = object[key] {
                    visit(child, name: key, path: "\(path)/\(key)")
                }
            }
        } else if let array = value as? [Any] {
            for (index, child) in array.enumerated() {
                visit(child, name: name, path: "\(path)/\(index)")
            }
        }
    }

    visit(root, name: "root", path: "#")
    return nodes
}

func isCanonicalPathNode(_ name: String) -> Bool {
    name.hasSuffix("_path") || [
        "canonical_relative_path",
        "exact_relative_path",
        "relative_path",
        "target_path",
    ].contains(name)
}

func isCanonicalTimestampNode(_ name: String) -> Bool {
    name == "canonical_timestamp" || name.hasSuffix("_timestamp") || name.hasSuffix("_at")
}

func isCanonicalDateNode(_ name: String) -> Bool {
    name == "canonical_date" || name.hasSuffix("_date")
}

func assertFormatMarker(_ schema: [String: Any], format: String, context: String) {
    #expect(schema["format"] as? String == format, "\(context) must declare format \(format)")
    #expect(
        schema["x-ifl-format-assertion-required"] as? Bool == true,
        "\(context) must require runtime custom-format assertion"
    )
}

func schemaAccepts(_ instance: Any, against schema: [String: Any], root: [String: Any]) -> Bool {
    if let reference = schema["$ref"] as? String {
        guard let target = resolve(reference: reference, in: root) as? [String: Any],
              schemaAccepts(instance, against: target, root: root)
        else { return false }
    }

    if let branches = schema["allOf"] as? [[String: Any]],
       !branches.allSatisfy({ schemaAccepts(instance, against: $0, root: root) })
    {
        return false
    }
    if let branches = schema["anyOf"] as? [[String: Any]],
       !branches.contains(where: { schemaAccepts(instance, against: $0, root: root) })
    {
        return false
    }
    if let branches = schema["oneOf"] as? [[String: Any]],
       branches.count(where: { schemaAccepts(instance, against: $0, root: root) }) != 1
    {
        return false
    }
    if let negated = schema["not"] as? [String: Any],
       schemaAccepts(instance, against: negated, root: root)
    {
        return false
    }
    if let condition = schema["if"] as? [String: Any] {
        if schemaAccepts(instance, against: condition, root: root) {
            if let consequence = schema["then"] as? [String: Any],
               !schemaAccepts(instance, against: consequence, root: root)
            {
                return false
            }
        } else if let alternative = schema["else"] as? [String: Any],
                  !schemaAccepts(instance, against: alternative, root: root)
        {
            return false
        }
    }

    if let expected = schema["const"], !jsonEquivalent(instance, expected) {
        return false
    }
    if let alternatives = schema["enum"] as? [Any],
       !alternatives.contains(where: { jsonEquivalent(instance, $0) })
    {
        return false
    }

    if let type = schema["type"] as? String, !jsonTypeMatches(instance, type: type) {
        return false
    }

    if let string = instance as? String {
        if let minimum = integerValue(schema["minLength"]), string.count < minimum { return false }
        if let maximum = integerValue(schema["maxLength"]), string.count > maximum { return false }
        if let pattern = schema["pattern"] as? String, !matches(pattern: pattern, string) { return false }
    }

    if let object = instance as? [String: Any] {
        if let required = schema["required"] as? [String],
           required.contains(where: { object[$0] == nil })
        {
            return false
        }
        if let properties = schema["properties"] as? [String: Any] {
            for (name, propertySchemaValue) in properties {
                guard let propertyValue = object[name] else { continue }
                if let propertySchema = propertySchemaValue as? [String: Any] {
                    guard schemaAccepts(propertyValue, against: propertySchema, root: root) else { return false }
                } else if let allowed = propertySchemaValue as? Bool, !allowed {
                    return false
                }
            }
            if schema["additionalProperties"] as? Bool == false,
               !Set(object.keys).isSubset(of: Set(properties.keys))
            {
                return false
            }
        }
    }

    if let array = instance as? [Any] {
        if let minimum = integerValue(schema["minItems"]), array.count < minimum { return false }
        if let maximum = integerValue(schema["maxItems"]), array.count > maximum { return false }
        if schema["uniqueItems"] as? Bool == true {
            for left in array.indices {
                for right in array.indices where right > left {
                    if jsonEquivalent(array[left], array[right]) { return false }
                }
            }
        }

        let prefixes = schema["prefixItems"] as? [[String: Any]] ?? []
        for index in array.indices where index < prefixes.count {
            if !schemaAccepts(array[index], against: prefixes[index], root: root) { return false }
        }

        let remainingStart = prefixes.isEmpty ? 0 : prefixes.count
        if array.count > remainingStart {
            if let itemSchema = schema["items"] as? [String: Any] {
                for index in remainingStart ..< array.count {
                    if !schemaAccepts(array[index], against: itemSchema, root: root) { return false }
                }
            } else if schema["items"] as? Bool == false {
                return false
            }
        }

        if let contains = schema["contains"] as? [String: Any] {
            let matchCount = array.count(where: { schemaAccepts($0, against: contains, root: root) })
            let minimum = integerValue(schema["minContains"]) ?? 1
            if matchCount < minimum { return false }
            if let maximum = integerValue(schema["maxContains"]), matchCount > maximum { return false }
        }
    }

    return true
}

func jsonTypeMatches(_ value: Any, type: String) -> Bool {
    switch type {
    case "object":
        value is [String: Any]
    case "array":
        value is [Any]
    case "string":
        value is String
    case "boolean":
        value is Bool
    case "integer":
        integerValue(value) != nil
    case "number":
        value is NSNumber && !(value is Bool)
    case "null":
        value is NSNull
    default:
        false
    }
}

func jsonEquivalent(_ lhs: Any, _ rhs: Any) -> Bool {
    guard JSONSerialization.isValidJSONObject([lhs]), JSONSerialization.isValidJSONObject([rhs]),
          let left = try? JSONSerialization.data(withJSONObject: [lhs], options: [.sortedKeys]),
          let right = try? JSONSerialization.data(withJSONObject: [rhs], options: [.sortedKeys])
    else { return false }
    return left == right
}

func declaredSchemaIDs(in value: Any) -> [String] {
    if let object = value as? [String: Any] {
        return object.flatMap { key, child in
            (key == "$id" ? [child as? String].compactMap(\.self) : []) + declaredSchemaIDs(in: child)
        }
    }
    if let array = value as? [Any] {
        return array.flatMap(declaredSchemaIDs(in:))
    }
    return []
}
