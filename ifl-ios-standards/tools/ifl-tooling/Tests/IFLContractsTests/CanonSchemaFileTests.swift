import Foundation
import Testing

@Suite("CanonSchemaFileTests")
struct CanonSchemaFileTests {
    @Test("the twelve required v1 schemas have exact filenames and stable identities")
    func requiredFilesAndStableIdentities() throws {
        var topLevelIDs: [String] = []
        var everyDeclaredID: [String] = []

        for expectation in schemaExpectations {
            let url = schemaURL(for: expectation.filename)
            let exists = FileManager.default.fileExists(atPath: url.path)
            #expect(exists, "Missing required Canon schema: \(expectation.filename)")
            guard exists else { continue }

            let schema = try decodeObject(at: url)
            #expect(schema["$schema"] as? String == "https://json-schema.org/draft/2020-12/schema")
            #expect(schema["$id"] as? String == expectation.id)

            if let id = schema["$id"] as? String {
                topLevelIDs.append(id)
            }
            everyDeclaredID.append(contentsOf: declaredSchemaIDs(in: schema))
        }

        #expect(topLevelIDs.count == Set(topLevelIDs).count)
        #expect(everyDeclaredID.count == Set(everyDeclaredID).count)
    }

    @Test("every v1 schema has a closed version-one object envelope")
    func closedVersionedObjectEnvelopes() throws {
        for expectation in schemaExpectations {
            guard let schema = try loadIfPresent(expectation.filename) else { continue }
            let properties = schema["properties"] as? [String: Any]
            let schemaVersion = properties?["schema_version"] as? [String: Any]

            #expect(schema["type"] as? String == "object", "\(expectation.filename) must be an object")
            #expect(schema["additionalProperties"] as? Bool == false, "\(expectation.filename) must reject unknown keys")
            #expect(isInteger(schemaVersion?["const"], equalTo: 1), "\(expectation.filename) must pin schema_version to 1")
            #expect(requiredNames(in: schema)?.contains("schema_version") == true)
        }
    }

    @Test("all twelve schemas use canonical sorted compact JSON with one trailing LF")
    func canonicalSchemaBytes() throws {
        for expectation in schemaExpectations {
            let url = schemaURL(for: expectation.filename)
            guard FileManager.default.fileExists(atPath: url.path) else { continue }

            let actual = try Data(contentsOf: url)
            let value = try JSONSerialization.jsonObject(with: actual)
            var canonical = try JSONSerialization.data(
                withJSONObject: value,
                options: [.sortedKeys, .withoutEscapingSlashes]
            )
            canonical.append(0x0A)

            let isCanonical = actual == canonical
            #expect(
                isCanonical,
                "\(expectation.filename) must equal sorted/minified JSON bytes followed by exactly one LF"
            )
        }
    }

    @Test("standalone contracts expose only their approved top-level fields")
    func standaloneTopLevelShapesAreExact() throws {
        for shape in standaloneShapes {
            guard let schema = try loadIfPresent(shape.filename) else { continue }
            let properties = try #require(schema["properties"] as? [String: Any])
            let required = try #require(requiredNames(in: schema))

            #expect(Set(properties.keys) == shape.fields, "\(shape.filename) has an unapproved top-level property")
            #expect(Set(required) == shape.fields, "\(shape.filename) must require every top-level property")
            #expect(required.count == Set(required).count, "\(shape.filename) repeats a required property")
        }
    }

    @Test("traceability schema pins the approved ordered twenty-six-requirement registry")
    func traceabilityPinsApprovedRegistry() throws {
        let schema = try #require(try loadIfPresent("traceability.schema.json"))
        let properties = try #require(schema["properties"] as? [String: Any])
        let requirements = try #require(properties["requirements"] as? [String: Any])

        #expect(integerValue(requirements["minItems"]) == approvedRequirements.count)
        #expect(integerValue(requirements["maxItems"]) == approvedRequirements.count)
        #expect(requirements["items"] as? Bool == false)
        let requirementSlots = requirements["prefixItems"] as? [[String: Any]]
        #expect(requirementSlots != nil, "requirements must declare ordered prefixItems")
        guard let requirementSlots else { return }
        #expect(requirementSlots.count == approvedRequirements.count)
        guard requirementSlots.count == approvedRequirements.count else { return }

        let requirementWitnesses: [[String: Any]] = approvedRequirements.map {
            [
                "schema_version": 1,
                "id": $0.id,
                "accountable_owner_role_id": $0.owner,
                "status": "planned",
            ]
        }
        #expect(schemaAccepts(requirementWitnesses, against: requirements, root: schema))

        for index in approvedRequirements.indices {
            let expected = approvedRequirements[index]
            #expect(
                stringConstants(for: "id", in: requirementSlots[index], root: schema) == [expected.id],
                "requirements prefixItems[\(index)] must pin \(expected.id)"
            )
            #expect(
                stringConstants(for: "accountable_owner_role_id", in: requirementSlots[index], root: schema) == [expected.owner],
                "requirements prefixItems[\(index)] must pin owner \(expected.owner)"
            )

            var wrongOwner = requirementWitnesses
            wrongOwner[index]["accountable_owner_role_id"] = "Wrong Owner"
            let acceptedWrongOwner = schemaAccepts(wrongOwner, against: requirements, root: schema)
            #expect(!acceptedWrongOwner, "requirements accepted wrong owner at prefixItems[\(index)]")
        }

        var wrongOrder = requirementWitnesses
        wrongOrder.swapAt(0, 1)
        #expect(!schemaAccepts(wrongOrder, against: requirements, root: schema))
        #expect(!schemaAccepts(Array(requirementWitnesses.dropLast()), against: requirements, root: schema))
        #expect(!schemaAccepts(requirementWitnesses + [requirementWitnesses[0]], against: requirements, root: schema))
    }

    @Test("traceability schema requires exactly one complete REQ-CONVERGENCE row")
    func traceabilityPinsCompleteConvergenceAllocation() throws {
        let schema = try #require(try loadIfPresent("traceability.schema.json"))
        let properties = try #require(schema["properties"] as? [String: Any])
        let traceability = try #require(properties["traceability"] as? [String: Any])

        let convergenceWitness = makeConvergenceTraceabilityWitness()
        #expect(integerValue(traceability["minContains"]) == 1)
        #expect(integerValue(traceability["maxContains"]) == 1)
        let convergenceConstraint = traceability["contains"] as? [String: Any]
        #expect(convergenceConstraint != nil, "traceability must declare a REQ-CONVERGENCE contains constraint")
        guard let convergenceConstraint else { return }
        #expect(schemaAccepts(convergenceWitness, against: convergenceConstraint, root: schema))
        #expect(schemaAccepts([convergenceWitness], against: traceability, root: schema))
        #expect(!schemaAccepts(
            [convergenceWitness, convergenceWitness],
            against: traceability,
            root: schema
        ))

        for mutation in makeIncompleteConvergenceWitnesses() {
            let acceptedIncomplete = schemaAccepts(mutation.value, against: convergenceConstraint, root: schema)
            #expect(
                !acceptedIncomplete,
                "REQ-CONVERGENCE contains constraint did not reject incomplete field \(mutation.field)"
            )
        }
    }

    @Test("fixture schema can express every Task 2 negative with exact operation and error vocabularies")
    func fixtureVocabularyIsCompleteAndCausal() throws {
        let schema = try #require(try loadIfPresent("fixture.schema.json"))
        let definitions = try #require(schema["$defs"] as? [String: Any])
        let mutation = try #require(definitions["mutation"] as? [String: Any])
        let branches = try #require(mutation["oneOf"] as? [[String: Any]])

        var operationSchemas: [String: [String: Any]] = [:]
        for branch in branches {
            let resolved = try #require(resolvedSchema(branch, root: schema))
            let operations = stringConstants(for: "operation", in: resolved, root: schema)
            let operation = try #require(operations.count == 1 ? operations[0] : nil)
            operationSchemas[operation] = resolved
        }
        #expect(Set(operationSchemas.keys) == Set(fixtureOperationFields.keys))

        for (operation, expectedFields) in fixtureOperationFields {
            let operationSchema = operationSchemas[operation]
            #expect(operationSchema != nil, "missing fixture mutation operation \(operation)")
            guard let operationSchema else { continue }
            let properties = try #require(operationSchema["properties"] as? [String: Any])
            let required = try #require(requiredNames(in: operationSchema))
            #expect(Set(properties.keys) == expectedFields)
            #expect(Set(required) == expectedFields)
        }

        for operation in ["json_add", "json_replace"] {
            guard let operationSchema = operationSchemas[operation] else { continue }
            for value: Any in [NSNull(), ["id": "REQ-CANON"], [1, 2, 3]] {
                let witness: [String: Any] = [
                    "operation": operation,
                    "relative_path": "registry/requirements.v1.json",
                    "json_pointer": "/requirements/0",
                    "value": value,
                ]
                let acceptedWitness = schemaAccepts(witness, against: operationSchema, root: schema)
                #expect(
                    acceptedWitness,
                    "\(operation) must carry any JSON value, including null/object/array"
                )
            }
        }

        let declaredErrorCodes = findStringEnum(named: "contract_error_code", in: schema)
        #expect(declaredErrorCodes != nil, "fixture expected contract must declare contract_error_code")
        let expectedErrorCodes = Set(declaredErrorCodes ?? [])
        #expect(expectedErrorCodes == contractErrorCodes)
        let missingOperations = task2NegativeCapabilities.filter { operationSchemas[$0.operation] == nil }
            .map { "\($0.fixture):\($0.operation)" }
        let missingErrorCodes = task2NegativeCapabilities.filter { !expectedErrorCodes.contains($0.errorCode) }
            .map { "\($0.fixture):\($0.errorCode)" }
        #expect(missingOperations.isEmpty, "Task 2 negatives lack operations \(missingOperations)")
        #expect(missingErrorCodes.isEmpty, "Task 2 negatives lack error codes \(missingErrorCodes)")
    }

    @Test("fixture base locator names the exact positive minimal root")
    func fixtureBaseLocatorIsExactAndCausal() throws {
        let schema = try #require(try loadIfPresent("fixture.schema.json"))
        let properties = try #require(schema["properties"] as? [String: Any])
        let baseFixture = try #require(properties["base_fixture"] as? [String: Any])

        #expect(schemaAccepts("positive/minimal", against: baseFixture, root: schema))
        #expect(!schemaAccepts("positive", against: baseFixture, root: schema))
        #expect(!schemaAccepts("minimal", against: baseFixture, root: schema))
        #expect(Set(baseFixture["enum"] as? [String] ?? []) == ["positive/minimal"])
    }

    @Test("derived artifact identifiers mirror Swift validators and artifact kinds are closed")
    func derivedArtifactIdentifiersAndKindsAreClosed() throws {
        let schema = try #require(try loadIfPresent("derived-artifact.schema.json"))
        let definitions = try #require(schema["$defs"] as? [String: Any])

        for corpus in derivedIdentifierCorpora {
            let definition = definitions[corpus.definition] as? [String: Any]
            #expect(definition != nil, "derived artifact schema must define \(corpus.definition)")
            guard let definition else { continue }
            let pattern = try #require(definition["pattern"] as? String)
            let rejectedValid = corpus.accepted.filter { !matches(pattern: pattern, $0) }
            let acceptedInvalid = corpus.rejected.filter { matches(pattern: pattern, $0) }
            #expect(rejectedValid.isEmpty, "\(corpus.definition) rejected Swift-valid witnesses \(rejectedValid)")
            #expect(acceptedInvalid.isEmpty, "\(corpus.definition) accepted Swift-invalid witnesses \(acceptedInvalid)")
        }

        let sourceBinding = definitions["source_semantic_binding"] as? [String: Any]
        #expect(sourceBinding != nil)
        if let sourceBinding {
            for corpus in derivedIdentifierCorpora {
                let sourceKind = try #require(corpus.sourceKind)
                let rejectedValid = corpus.accepted.filter { sourceID in
                    let witness: [String: Any] = [
                        "source_kind": sourceKind,
                        "source_id": sourceID,
                        "digest": String(repeating: "0", count: 64),
                    ]
                    return !schemaAccepts(witness, against: sourceBinding, root: schema)
                }
                let acceptedInvalid = corpus.rejected.filter { sourceID in
                    let witness: [String: Any] = [
                        "source_kind": sourceKind,
                        "source_id": sourceID,
                        "digest": String(repeating: "0", count: 64),
                    ]
                    return schemaAccepts(witness, against: sourceBinding, root: schema)
                }
                #expect(rejectedValid.isEmpty, "source binding rejected Swift-valid \(corpus.definition) witnesses \(rejectedValid)")
                #expect(acceptedInvalid.isEmpty, "source binding accepted Swift-invalid \(corpus.definition) witnesses \(acceptedInvalid)")
            }
        }

        if let entry = definitions["derived_registration_entry"] as? [String: Any],
           let entryProperties = entry["properties"] as? [String: Any],
           let artifactKind = entryProperties["artifact_kind"] as? [String: Any]
        {
            #expect(Set(artifactKind["enum"] as? [String] ?? []) == artifactKinds)
        } else {
            Issue.record("derived artifact schema must type derived_registration_entry.artifact_kind")
        }
    }

    @Test("product version stays strict SemVer and compatibility selector vocabulary is closed")
    func compatibilityVersionSchemesAreTyped() throws {
        let schema = try #require(try loadIfPresent("compatibility-matrix.schema.json"))
        let properties = try #require(schema["properties"] as? [String: Any])
        let definitions = try #require(schema["$defs"] as? [String: Any])

        let productVersion = properties["product_version"] as? [String: Any]
        let canonVersion = properties["canon_version"] as? [String: Any]
        let unmatched = properties["unmatched_version_status"] as? [String: Any]
        #expect(productVersion != nil)
        #expect(canonVersion != nil)
        #expect(unmatched != nil)
        if let canonVersion {
            #expect(isInteger(canonVersion["const"], equalTo: 1))
        }
        if let unmatched {
            #expect(Set(unmatched["enum"] as? [String] ?? []) == ["unknown", "unsupported"])
        }

        let semver = definitions["semantic_version"] as? [String: Any]
        #expect(semver != nil, "compatibility schema must define strict semantic_version")
        if let semver {
            let semverPattern = try #require(semver["pattern"] as? String)
            for witness in semanticVersionWitnesses.accepted {
                #expect(matches(pattern: semverPattern, witness))
                if let productVersion {
                    #expect(schemaAccepts(witness, against: productVersion, root: schema))
                }
            }
            for witness in semanticVersionWitnesses.rejected {
                #expect(!matches(pattern: semverPattern, witness))
                if let productVersion {
                    #expect(!schemaAccepts(witness, against: productVersion, root: schema))
                }
            }
        }

        let selector = definitions["compatibility_selector"] as? [String: Any]
        #expect(selector != nil, "compatibility schema must define compatibility_selector")
        if let selector {
            #expect(
                stringVocabulary(for: "kind", in: selector, root: schema)
                    == compatibilitySelectorKinds
            )
            #expect(
                stringVocabulary(for: "version_scheme", in: selector, root: schema)
                    == compatibilityVersionSchemes
            )
        }
    }

    @Test("compatibility rows use all nine subjects with causal exact and bounded selectors")
    func compatibilitySubjectsAndSelectorsAreClosed() throws {
        let schema = try #require(try loadIfPresent("compatibility-matrix.schema.json"))
        let definitions = try #require(schema["$defs"] as? [String: Any])

        let row = definitions["compatibility_row"] as? [String: Any]
        #expect(row != nil, "compatibility schema must define compatibility_row")
        guard let row else { return }
        let rowProperties = try #require(row["properties"] as? [String: Any])
        let subject = try #require(rowProperties["subject_kind"] as? [String: Any])
        #expect(Set(subject["enum"] as? [String] ?? []) == compatibilitySubjects)
        #expect(Set(requiredNames(in: row) ?? []) == [
            "id", "subject_kind", "subject_id", "selector", "support_status", "tested",
            "owner_role_id", "evidence_ids", "eol_policy",
        ])
        #expect(Set((rowProperties["support_status"] as? [String: Any])?["enum"] as? [String] ?? []) == [
            "supported", "deprecated", "unsupported", "unknown",
        ])
        #expect((rowProperties["tested"] as? [String: Any])?["type"] as? String == "boolean")

        let selectorBranches = row["oneOf"] as? [[String: Any]]
        #expect(selectorBranches != nil, "compatibility_row must discriminate typed selectors")
        var subjectSelectors: [String: [String: Any]] = [:]
        for branch in selectorBranches ?? [] {
            let branchSubjects = stringConstants(for: "subject_kind", in: branch, root: schema)
            #expect(branchSubjects.count == 1)
            guard let branchSubject = branchSubjects.first,
                  branchSubjects.count == 1,
                  let selector = propertySchemas(for: "selector", in: branch, root: schema).last,
                  let resolvedSelector = resolvedSchema(selector, root: schema)
            else { continue }
            subjectSelectors[branchSubject] = resolvedSelector
        }
        #expect(Set(subjectSelectors.keys) == compatibilitySubjects)
        #expect(Set(compatibilitySelectorExpectations.map(\.subjectKind)) == compatibilitySubjects)

        for expectation in compatibilitySelectorExpectations {
            let selector = subjectSelectors[expectation.subjectKind]
            #expect(selector != nil, "missing selector for \(expectation.subjectKind)")
            guard let selector else { continue }

            let expectedKinds: Set<String> = expectation.supportsBounded
                ? ["exact", "bounded_range"]
                : ["exact"]
            #expect(stringVocabulary(for: "kind", in: selector, root: schema) == expectedKinds)
            #expect(
                stringVocabulary(for: "version_scheme", in: selector, root: schema)
                    == [expectation.versionScheme]
            )

            let exact: [String: Any] = [
                "kind": "exact",
                "version_scheme": expectation.versionScheme,
                "value": expectation.exactValue,
            ]
            #expect(
                schemaAccepts(exact, against: selector, root: schema),
                "\(expectation.subjectKind) rejected exact \(expectation.exactValue)"
            )

            for field in ["kind", "version_scheme", "value"] {
                var missing = exact
                missing.removeValue(forKey: field)
                #expect(
                    !schemaAccepts(missing, against: selector, root: schema),
                    "\(expectation.subjectKind) accepted exact selector missing \(field)"
                )
            }

            var mixedExact = exact
            mixedExact["lower_bound"] = expectation.lowerBound ?? expectation.exactValue
            #expect(
                !schemaAccepts(mixedExact, against: selector, root: schema),
                "\(expectation.subjectKind) accepted mixed exact/range fields"
            )

            for invalidValue in ["latest", expectation.leadingZeroAlias] {
                var invalid = exact
                invalid["value"] = invalidValue
                #expect(
                    !schemaAccepts(invalid, against: selector, root: schema),
                    "\(expectation.subjectKind) accepted invalid exact value \(invalidValue)"
                )
            }

            var wrongScheme = exact
            wrongScheme["version_scheme"] = expectation.alternateVersionScheme
            #expect(
                !schemaAccepts(wrongScheme, against: selector, root: schema),
                "\(expectation.subjectKind) accepted wrong version scheme"
            )

            var unknownKind = exact
            unknownKind["kind"] = "range"
            #expect(
                !schemaAccepts(unknownKind, against: selector, root: schema),
                "\(expectation.subjectKind) accepted unknown selector kind"
            )

            let bounded: [String: Any] = [
                "kind": "bounded_range",
                "version_scheme": expectation.versionScheme,
                "lower_bound": expectation.lowerBound ?? expectation.exactValue,
                "upper_bound": expectation.upperBound ?? expectation.exactValue,
                "lower_inclusive": true,
                "upper_inclusive": true,
            ]
            if expectation.supportsBounded {
                #expect(
                    schemaAccepts(bounded, against: selector, root: schema),
                    "\(expectation.subjectKind) rejected a complete bounded selector"
                )

                for field in [
                    "kind", "version_scheme", "lower_bound", "upper_bound",
                    "lower_inclusive", "upper_inclusive",
                ] {
                    var missing = bounded
                    missing.removeValue(forKey: field)
                    #expect(
                        !schemaAccepts(missing, against: selector, root: schema),
                        "\(expectation.subjectKind) accepted bounded selector missing \(field)"
                    )
                }

                var mixedBounded = bounded
                mixedBounded["value"] = expectation.exactValue
                #expect(
                    !schemaAccepts(mixedBounded, against: selector, root: schema),
                    "\(expectation.subjectKind) accepted mixed range/exact fields"
                )

                var latestBound = bounded
                latestBound["lower_bound"] = "latest"
                #expect(
                    !schemaAccepts(latestBound, against: selector, root: schema),
                    "\(expectation.subjectKind) accepted latest as a lower bound"
                )

                var leadingZeroBound = bounded
                leadingZeroBound["upper_bound"] = expectation.leadingZeroAlias
                #expect(
                    !schemaAccepts(leadingZeroBound, against: selector, root: schema),
                    "\(expectation.subjectKind) accepted a leading-zero upper bound"
                )

                var wrongBoundScheme = bounded
                wrongBoundScheme["version_scheme"] = expectation.alternateVersionScheme
                #expect(
                    !schemaAccepts(wrongBoundScheme, against: selector, root: schema),
                    "\(expectation.subjectKind) accepted a wrong bounded version scheme"
                )

                for field in ["lower_inclusive", "upper_inclusive"] {
                    var nonBoolean = bounded
                    nonBoolean[field] = "true"
                    #expect(
                        !schemaAccepts(nonBoolean, against: selector, root: schema),
                        "\(expectation.subjectKind) accepted non-Boolean \(field)"
                    )
                }
            } else {
                #expect(
                    !schemaAccepts(bounded, against: selector, root: schema),
                    "\(expectation.subjectKind) must support exact selectors only"
                )
            }
        }

        let nonBlank = definitions["non_blank"] as? [String: Any]
        #expect(nonBlank != nil, "compatibility metadata must share a non_blank definition")
        if let nonBlank {
            for rejected in ["", " ", " Owner", "Owner ", "A\u{0085}B"] {
                #expect(!schemaAccepts(rejected, against: nonBlank, root: schema))
            }
            for field in ["owner_role_id", "eol_policy"] {
                guard let fieldSchema = rowProperties[field] as? [String: Any] else {
                    Issue.record("compatibility_row must declare \(field)")
                    continue
                }
                #expect(schemaAccepts("Owner", against: fieldSchema, root: schema))
                #expect(!schemaAccepts(" ", against: fieldSchema, root: schema))
                #expect(!schemaAccepts("A\u{0085}B", against: fieldSchema, root: schema))
            }
        }
    }

    @Test("compatibility rows explicitly cover every required subject")
    func compatibilityDeclaresAllRequiredCoverage() throws {
        let schema = try #require(try loadIfPresent("compatibility-matrix.schema.json"))
        let properties = try #require(schema["properties"] as? [String: Any])

        let rows = properties["rows"] as? [String: Any]
        #expect(rows != nil)
        guard let rows else { return }
        if let itemSchema = rows["items"] as? [String: Any] {
            #expect(itemSchema["$ref"] as? String == "#/$defs/compatibility_row")
        } else {
            Issue.record("compatibility rows must use compatibility_row as items")
        }
        let coverage = rows["allOf"] as? [[String: Any]]
        #expect(coverage != nil, "rows must encode minContains coverage per required subject")
        let coveredSubjects = Set((coverage ?? []).compactMap { coverageRule -> String? in
            guard integerValue(coverageRule["minContains"]) == 1,
                  let contains = coverageRule["contains"] as? [String: Any]
            else { return nil }
            let subjects = stringConstants(for: "subject_kind", in: contains, root: schema)
            return subjects.count == 1 ? subjects[0] : nil
        })
        #expect(coveredSubjects == compatibilitySubjects)
    }

    @Test("compatibility deprecation date is required only for deprecated rows")
    func compatibilityDeprecationContractIsCausal() throws {
        let schema = try #require(try loadIfPresent("compatibility-matrix.schema.json"))
        let definitions = try #require(schema["$defs"] as? [String: Any])
        let row = definitions["compatibility_row"] as? [String: Any]
        #expect(row != nil)
        guard let row else { return }

        let deprecationRule = findConditional(
            property: "support_status",
            equals: "deprecated",
            in: row,
            root: schema
        )
        #expect(deprecationRule != nil)
        guard let deprecationRule else { return }
        let acceptsDeprecatedWithDate = schemaAccepts(
            ["support_status": "deprecated", "deprecation_date": "2026-07-11"],
            against: deprecationRule,
            root: schema
        )
        let acceptsDeprecatedWithoutDate = schemaAccepts(
            ["support_status": "deprecated"],
            against: deprecationRule,
            root: schema
        )
        let acceptsSupportedWithoutDate = schemaAccepts(
            ["support_status": "supported"],
            against: deprecationRule,
            root: schema
        )
        let acceptsSupportedWithDate = schemaAccepts(
            ["support_status": "supported", "deprecation_date": "2026-07-11"],
            against: deprecationRule,
            root: schema
        )
        #expect(acceptsDeprecatedWithDate)
        #expect(!acceptsDeprecatedWithoutDate)
        #expect(acceptsSupportedWithoutDate)
        #expect(!acceptsSupportedWithDate)
    }

    @Test("canonical strings, paths, dates, and timestamps expose enforced lexical contracts")
    func canonicalStringAndFormatMarkersAreExplicit() throws {
        for expectation in schemaExpectations {
            guard let schema = try loadIfPresent(expectation.filename) else { continue }
            if let definitions = schema["$defs"] as? [String: Any],
               let nonBlank = definitions["non_blank"] as? [String: Any]
            {
                let pattern = try #require(nonBlank["pattern"] as? String)
                #expect(matches(pattern: pattern, "Owner"))
                let invalid = ["", " ", "Owner ", "A\u{007F}B", "A\u{0085}B", "A\u{009F}B"]
                let acceptedInvalid = invalid.filter { matches(pattern: pattern, $0) }
                #expect(
                    acceptedInvalid.isEmpty,
                    "\(expectation.filename) non_blank accepted \(acceptedInvalid.map(\.debugDescription))"
                )
            }

            for named in namedSchemaNodes(in: schema) {
                guard named.schema["type"] as? String == "string" else { continue }
                if isCanonicalPathNode(named.name) {
                    assertFormatMarker(
                        named.schema,
                        format: "ifl-canonical-relative-path-v1",
                        context: "\(expectation.filename):\(named.path)"
                    )
                    let pattern = try #require(named.schema["pattern"] as? String)
                    let acceptedInvalid = invalidCanonicalPaths.filter { matches(pattern: pattern, $0) }
                    #expect(
                        acceptedInvalid.isEmpty,
                        "\(expectation.filename):\(named.path) accepted invalid paths \(acceptedInvalid.map(\.debugDescription))"
                    )
                } else if isCanonicalTimestampNode(named.name) {
                    assertFormatMarker(
                        named.schema,
                        format: "ifl-canonical-timestamp-v1",
                        context: "\(expectation.filename):\(named.path)"
                    )
                    let pattern = try #require(named.schema["pattern"] as? String)
                    #expect(matches(pattern: pattern, "2026-07-11T23:59:58.123Z"))
                    let acceptedInvalid = invalidCanonicalTimestamps.filter { matches(pattern: pattern, $0) }
                    #expect(
                        acceptedInvalid.isEmpty,
                        "\(expectation.filename):\(named.path) accepted invalid timestamps \(acceptedInvalid)"
                    )
                } else if isCanonicalDateNode(named.name) {
                    assertFormatMarker(
                        named.schema,
                        format: "ifl-canonical-date-v1",
                        context: "\(expectation.filename):\(named.path)"
                    )
                    let pattern = try #require(named.schema["pattern"] as? String)
                    #expect(matches(pattern: pattern, "2026-07-11"))
                    let acceptedInvalid = invalidCanonicalDates.filter { matches(pattern: pattern, $0) }
                    #expect(
                        acceptedInvalid.isEmpty,
                        "\(expectation.filename):\(named.path) accepted invalid dates \(acceptedInvalid)"
                    )
                }
            }
        }
    }

    @Test("record schemas exactly mirror committed Codable top-level fields")
    func codableRecordPropertyParity() throws {
        for shape in recordShapes {
            guard let schema = try loadIfPresent(shape.filename) else { continue }
            let properties = try #require(schema["properties"] as? [String: Any])
            let required = try #require(requiredNames(in: schema))
            let expectedProperties = shape.required.union(shape.optional)

            #expect(Set(properties.keys) == expectedProperties, "\(shape.filename) property keys drifted from Codable")
            #expect(Set(required) == shape.required, "\(shape.filename) required keys drifted from Codable optionality")
            #expect(required.count == Set(required).count, "\(shape.filename) repeats a required key")
            #expect(Set(required).isDisjoint(with: shape.optional), "\(shape.filename) marks an optional Codable field as required")
        }
    }

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

    private var pluginRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func schemaURL(for filename: String) -> URL {
        pluginRoot.appendingPathComponent("standards/canon/schemas/v1/\(filename)")
    }

    private func loadIfPresent(_ filename: String) throws -> [String: Any]? {
        let url = schemaURL(for: filename)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try decodeObject(at: url)
    }

    private func decodeObject(at url: URL) throws -> [String: Any] {
        try #require(
            JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any],
            "Schema must contain one JSON object: \(url.lastPathComponent)"
        )
    }
}

private struct SchemaExpectation {
    let filename: String
    let id: String
}

private struct RecordShape {
    let filename: String
    let required: Set<String>
    let optional: Set<String>
}

private struct StandaloneShape {
    let filename: String
    let fields: Set<String>
}

private struct RequirementOwner {
    let id: String
    let owner: String
}

private struct NegativeFixtureCapability {
    let fixture: String
    let operation: String
    let errorCode: String
}

private struct IdentifierCorpus {
    let definition: String
    let sourceKind: String?
    let accepted: [String]
    let rejected: [String]
}

private struct StringWitnessCorpus {
    let accepted: [String]
    let rejected: [String]
}

private struct CompatibilitySelectorExpectation {
    let subjectKind: String
    let versionScheme: String
    let exactValue: String
    let lowerBound: String?
    let upperBound: String?
    let leadingZeroAlias: String

    var supportsBounded: Bool {
        lowerBound != nil && upperBound != nil
    }

    var alternateVersionScheme: String {
        versionScheme == "semver" ? "numeric_dotted" : "semver"
    }
}

private struct NamedSchemaNode {
    let name: String
    let path: String
    let schema: [String: Any]
}

private let schemaExpectations: [SchemaExpectation] = [
    .init(filename: "rule.schema.json", id: "urn:ifl:standards:schema:rule:v1"),
    .init(filename: "profile.schema.json", id: "urn:ifl:standards:schema:profile:v1"),
    .init(filename: "adr-metadata.schema.json", id: "urn:ifl:standards:schema:adr-metadata:v1"),
    .init(filename: "chapter.schema.json", id: "urn:ifl:standards:schema:chapter:v1"),
    .init(filename: "candidate-overlay.schema.json", id: "urn:ifl:standards:schema:candidate-overlay:v1"),
    .init(filename: "activation-receipt.schema.json", id: "urn:ifl:standards:schema:activation-receipt:v1"),
    .init(filename: "exception.schema.json", id: "urn:ifl:standards:schema:exception:v1"),
    .init(filename: "fixture.schema.json", id: "urn:ifl:standards:schema:fixture:v1"),
    .init(filename: "derived-artifact.schema.json", id: "urn:ifl:standards:schema:derived-artifact:v1"),
    .init(filename: "derived-registration-delta.schema.json", id: "urn:ifl:standards:schema:derived-registration-delta:v1"),
    .init(filename: "traceability.schema.json", id: "urn:ifl:standards:schema:traceability:v1"),
    .init(filename: "compatibility-matrix.schema.json", id: "urn:ifl:standards:schema:compatibility-matrix:v1"),
]

private let strictStandaloneSchemas = [
    "fixture.schema.json",
    "derived-artifact.schema.json",
    "compatibility-matrix.schema.json",
]

private let standaloneShapes: [StandaloneShape] = [
    .init(
        filename: "fixture.schema.json",
        fields: ["schema_version", "fixture_id", "base_fixture", "mutations", "expected"]
    ),
    .init(
        filename: "derived-artifact.schema.json",
        fields: ["schema_version", "id", "entries"]
    ),
    .init(
        filename: "compatibility-matrix.schema.json",
        fields: ["schema_version", "product_version", "canon_version", "unmatched_version_status", "rows"]
    ),
]

private let approvedRequirements: [RequirementOwner] = [
    .init(id: "ENT-ACCESSIBILITY", owner: "Accessibility Owner"),
    .init(id: "ENT-CONCURRENCY", owner: "Concurrency Chapter Owner"),
    .init(id: "ENT-DATA", owner: "Data Lifecycle Owner"),
    .init(id: "ENT-OBSERVABILITY", owner: "Operability Owner"),
    .init(id: "ENT-PERFORMANCE", owner: "Performance Owner"),
    .init(id: "ENT-PRIVACY", owner: "Privacy Owner"),
    .init(id: "ENT-SECURITY", owner: "Security Owner"),
    .init(id: "ENT-SUPPLY", owner: "Security/Legal Owner"),
    .init(id: "ENT-SWIFTUI", owner: "SwiftUI Profile Owner"),
    .init(id: "ENT-TESTING", owner: "Testing Owner"),
    .init(id: "P0-1", owner: "Workflow Maintainer"),
    .init(id: "P0-2", owner: "Runtime/Agent Owner"),
    .init(id: "P0-3", owner: "Verification Owner"),
    .init(id: "P0-4", owner: "Canon Maintainer"),
    .init(id: "P0-5", owner: "Scaffolding Owner"),
    .init(id: "P0-6", owner: "Workflow Maintainer"),
    .init(id: "P0-7", owner: "Security/Compliance Owner"),
    .init(id: "REQ-AGENTS", owner: "Runtime/Agent Owner"),
    .init(id: "REQ-BOARDY", owner: "iOS Profile Owner"),
    .init(id: "REQ-CANON", owner: "Canon Maintainer"),
    .init(id: "REQ-CONVERGENCE", owner: "Workflow Maintainer"),
    .init(id: "REQ-EFFECTS", owner: "Workflow Maintainer"),
    .init(id: "REQ-MIGRATION", owner: "Release Steward"),
    .init(id: "REQ-RC", owner: "Release Steward"),
    .init(id: "REQ-RUNTIME", owner: "Runtime/Agent Owner"),
    .init(id: "REQ-VERIFY", owner: "Verification Owner"),
]

private let convergenceInternalChecks = [
    "CHK-WF-CONV-BASELINE-001",
    "CHK-WF-CONV-INVENTORY-001",
    "CHK-WF-CONV-REGISTER-001",
    "CHK-WF-CONV-DISPOSITION-001",
    "CHK-WF-CONV-REMEDIATION-001",
    "CHK-WF-CONV-CONFIRMATION-001",
    "CHK-WF-CONV-EXCEPTION-001",
    "CHK-WF-CONV-INVALIDATION-001",
]

private let convergencePublicChecks = [
    "CHK-FLOW-CONVERGENCE",
    "CHK-AGENT-CONVERGENCE",
    "CHK-EVIDENCE-CONVERGENCE",
    "CHK-RUN-CONVERGENCE",
    "CHK-RELEASE-CONVERGENCE",
]

private func makeConvergenceFixtureMappings() -> [[String: Any]] {
    (convergenceInternalChecks + convergencePublicChecks).map { checkID in
        let suffix = if checkID.hasPrefix("CHK-WF-CONV-") {
            String(checkID.dropFirst("CHK-WF-CONV-".count))
        } else {
            String(checkID.dropFirst("CHK-".count))
        }
        return [
            "check_id": checkID,
            "positive_fixture_ids": ["FIX-WF-CONV-\(suffix)-PASS"],
            "negative_fixture_ids": ["FIX-WF-CONV-\(suffix)-FAIL-001"],
        ]
    }
}

private func makeConvergenceTraceabilityWitness() -> [String: Any] {
    [
        "schema_version": 1,
        "requirement_id": "REQ-CONVERGENCE",
        "accountable_owner_role_id": "Workflow Maintainer",
        "rule_bindings": [],
        "internal_check_namespace": "CHK-WF-CONV-*",
        "internal_check_ids": convergenceInternalChecks,
        "public_check_ids": convergencePublicChecks,
        "fixture_namespace": "FIX-WF-CONV-*",
        "fixture_mappings": makeConvergenceFixtureMappings(),
        "required_evidence_kinds": [
            "review_confirmation_receipt/v1",
            "review_convergence_receipt/v1",
        ],
    ]
}

private func makeIncompleteConvergenceWitnesses() -> [(field: String, value: [String: Any])] {
    let mutations: [(String, Any)] = [
        ("schema_version", 2),
        ("requirement_id", "REQ-CANON"),
        ("accountable_owner_role_id", "Wrong Owner"),
        ("rule_bindings", [["rule_id": "WF-CONV-001", "owner_role_id": "Workflow Maintainer"]]),
        ("internal_check_namespace", "CHK-WF-OTHER-*"),
        ("internal_check_ids", Array(convergenceInternalChecks.dropLast())),
        ("public_check_ids", Array(convergencePublicChecks.reversed())),
        ("fixture_namespace", "FIX-WF-OTHER-*"),
        ("fixture_mappings", Array(makeConvergenceFixtureMappings().dropLast())),
        ("required_evidence_kinds", ["review_confirmation_receipt/v1"]),
    ]
    return mutations.map { field, replacement in
        var value = makeConvergenceTraceabilityWitness()
        value[field] = replacement
        return (field, value)
    }
}

private let fixtureOperationFields: [String: Set<String>] = [
    "json_add": ["operation", "relative_path", "json_pointer", "value"],
    "json_replace": ["operation", "relative_path", "json_pointer", "value"],
    "json_remove": ["operation", "relative_path", "json_pointer"],
    "write_utf8": ["operation", "relative_path", "utf8_content"],
    "remove_file": ["operation", "relative_path"],
]

private let contractErrorCodes: Set<String> = [
    "invalid_identifier",
    "invalid_run_id_filesystem_component",
    "invalid_candidate_generation",
    "candidate_generation_overflow",
    "invalid_sha256",
    "unsupported_schema_version",
    "invalid_canon_version",
    "duplicate_identifier",
    "reused_identifier",
    "unresolved_reference",
    "invalid_contract",
    "digest_mismatch",
    "unexpected_keys",
]

private let task2NegativeCapabilities: [NegativeFixtureCapability] = [
    .init(fixture: "duplicate-id", operation: "json_add", errorCode: "duplicate_identifier"),
    .init(fixture: "unknown-version", operation: "json_replace", errorCode: "unsupported_schema_version"),
    .init(fixture: "reused-id", operation: "json_replace", errorCode: "reused_identifier"),
    .init(fixture: "orphan-requirement", operation: "json_replace", errorCode: "unresolved_reference"),
    .init(fixture: "missing-convergence-traceability", operation: "json_remove", errorCode: "unresolved_reference"),
    .init(fixture: "accepted-adr-incomplete", operation: "json_remove", errorCode: "invalid_contract"),
]

private let derivedIdentifierCorpora: [IdentifierCorpus] = [
    .init(
        definition: "rule_id",
        sourceKind: "rule",
        accepted: ["TEST-CANON-001", "1-2-999"],
        rejected: ["TEST-001", "TEST-CANON-01", "test-CANON-001", "TEST--001", "TEST-CANON-001\n"]
    ),
    .init(
        definition: "profile_id",
        sourceKind: "profile",
        accepted: ["minimal", "boardy-vip", "swift6"],
        rejected: ["Minimal", "boardy--vip", "1minimal", "minimal\n"]
    ),
    .init(
        definition: "adr_id",
        sourceKind: "adr",
        accepted: ["ADR-0001", "ADR-9999"],
        rejected: ["ADR-1", "ADR-00001", "adr-0001", "ADR-0001\n"]
    ),
    .init(
        definition: "requirement_id",
        sourceKind: "requirement",
        accepted: ["P0-1", "P3-42", "ENT-CONCURRENCY", "REQ-CONVERGENCE"],
        rejected: ["P4-1", "P0-0", "P0-01", "ENT-", "REQ--CANON", "req-canon", "REQ-CANON\n"]
    ),
    .init(
        definition: "slug",
        sourceKind: "chapter",
        accepted: ["security", "swiftui-production", "1chapter"],
        rejected: ["Chapter", "chapter--x", "_chapter", "chapter\n"]
    ),
]

private let artifactKinds: Set<String> = [
    "constitution",
    "rulebook",
    "specification",
    "compact_reference",
    "checklist",
    "guide",
    "skill",
    "agent",
    "template",
    "scaffold",
    "wrapper",
    "process_contract",
    "example",
    "migration_guide",
]

private let compatibilitySubjects: Set<String> = [
    "claude_host",
    "codex_host",
    "macos",
    "xcode",
    "swift_language_mode",
    "deployment_baseline",
    "boardy",
    "library",
    "build_profile",
]

private let compatibilitySelectorKinds: Set<String> = [
    "bounded_range",
    "exact",
]

private let compatibilityVersionSchemes: Set<String> = [
    "deployment_target",
    "identifier",
    "numeric_dotted",
    "semver",
    "swift_language_mode",
]

private let compatibilitySelectorExpectations: [CompatibilitySelectorExpectation] = [
    .init(
        subjectKind: "claude_host",
        versionScheme: "semver",
        exactValue: "1.0.0",
        lowerBound: "1.0.0",
        upperBound: "2.0.0",
        leadingZeroAlias: "01.0.0"
    ),
    .init(
        subjectKind: "codex_host",
        versionScheme: "semver",
        exactValue: "1.2.3",
        lowerBound: "1.0.0",
        upperBound: "2.0.0",
        leadingZeroAlias: "01.2.3"
    ),
    .init(
        subjectKind: "macos",
        versionScheme: "numeric_dotted",
        exactValue: "15.0",
        lowerBound: "14.0",
        upperBound: "15.0",
        leadingZeroAlias: "015.0"
    ),
    .init(
        subjectKind: "xcode",
        versionScheme: "numeric_dotted",
        exactValue: "16.4",
        lowerBound: "16.0",
        upperBound: "16.4",
        leadingZeroAlias: "016.4"
    ),
    .init(
        subjectKind: "swift_language_mode",
        versionScheme: "swift_language_mode",
        exactValue: "6",
        lowerBound: nil,
        upperBound: nil,
        leadingZeroAlias: "06"
    ),
    .init(
        subjectKind: "deployment_baseline",
        versionScheme: "deployment_target",
        exactValue: "18.0",
        lowerBound: "17.0",
        upperBound: "18.0",
        leadingZeroAlias: "018.0"
    ),
    .init(
        subjectKind: "boardy",
        versionScheme: "semver",
        exactValue: "1.0.0",
        lowerBound: "1.0.0",
        upperBound: "2.0.0",
        leadingZeroAlias: "01.0.0"
    ),
    .init(
        subjectKind: "library",
        versionScheme: "semver",
        exactValue: "2.3.4",
        lowerBound: "2.0.0",
        upperBound: "3.0.0",
        leadingZeroAlias: "02.3.4"
    ),
    .init(
        subjectKind: "build_profile",
        versionScheme: "identifier",
        exactValue: "build-release",
        lowerBound: nil,
        upperBound: nil,
        leadingZeroAlias: "01-release"
    ),
]

private let semanticVersionWitnesses = StringWitnessCorpus(
    accepted: ["0.0.0", "1.0.0", "1.0.0-rc.1", "1.2.3+build.5"],
    rejected: ["1", "1.0", "01.0.0", "1.0.0-01", "latest", " 1.0.0", "1.0.0\n"]
)

private let invalidCanonicalPaths = [
    "",
    "/absolute",
    "registry//a.json",
    "registry/./a.json",
    "registry/../a.json",
    "registry\\a.json",
    "registry/a\u{0000}.json",
    "registry/a\u{0085}.json",
    "registry/a\u{009F}.json",
    "registry/a\u{2028}.json",
    "registry/a\u{2029}.json",
    "activations/a\u{0085}.approval.json",
    "activations/a\u{2028}.approval.json",
]

private let invalidCanonicalTimestamps = [
    "2026-00-11T23:59:58.123Z",
    "2026-13-11T23:59:58.123Z",
    "2026-07-00T23:59:58.123Z",
    "2026-07-32T23:59:58.123Z",
    "2026-07-11T24:59:58.123Z",
    "2026-07-11T23:60:58.123Z",
    "2026-07-11T23:59:60.123Z",
    "2026-07-11T23:59:58Z",
    "2026-07-11T23:59:58.1234Z",
    "2026-07-11T23:59:58.123+00:00",
    "2026-07-11T23:59:58.123Z\n",
]

private let invalidCanonicalDates = [
    "2026-00-11",
    "2026-13-11",
    "2026-07-00",
    "2026-07-32",
    "2026-7-11",
    "2026-07-11T00:00:00.000Z",
    "2026-07-11\n",
]

private let recordShapes: [RecordShape] = [
    .init(
        filename: "rule.schema.json",
        required: [
            "schema_version", "id", "level", "statement", "scope", "profile_ids", "severity",
            "risk_class", "rationale_adrs", "evidence", "enforcement", "exception_policy", "lifecycle",
            "introduced_in", "effective_in", "examples_required", "compliant_example_ids",
            "non_compliant_example_ids",
        ],
        optional: ["replacement_id"]
    ),
    .init(
        filename: "profile.schema.json",
        required: [
            "schema_version", "id", "display_name", "description", "owner_role_id", "applicability",
            "inherits_profile_ids", "rule_ids",
        ],
        optional: []
    ),
    .init(
        filename: "adr-metadata.schema.json",
        required: [
            "schema_version", "id", "title", "status", "owner_role_id", "decision_date", "markdown_digest",
            "context", "decision", "alternatives", "consequences", "migration", "affected_rule_ids",
            "affected_profile_ids", "verification_impact", "check_ids", "fixture_ids", "reference_artifact_ids",
            "migration_ids", "supersedes_adr_ids",
        ],
        optional: ["superseded_by", "accepted_at"]
    ),
    .init(
        filename: "chapter.schema.json",
        required: [
            "schema_version", "id", "requirement_id", "title", "owner_role_id", "rationale", "applicability",
            "rule_ids", "rationale_adr_ids", "compliant_example_ids", "non_compliant_example_ids", "check_ids",
            "positive_fixture_ids", "negative_fixture_ids", "required_evidence_kinds", "review_checklist_ids",
            "exception_policy", "review_cadence", "required_rule_dependencies",
        ],
        optional: []
    ),
    .init(
        filename: "traceability.schema.json",
        required: ["schema_version", "requirements", "traceability"],
        optional: []
    ),
    .init(
        filename: "candidate-overlay.schema.json",
        required: [
            "schema_version", "overlay_id", "target_canon_version", "target_product_version",
            "base_snapshot_content_digest", "reviewed_components", "rules", "profiles", "adrs", "chapters",
            "requirement_traceability", "checks", "fixtures", "migrations", "indexes",
            "derived_registration_deltas", "activation_fields", "expected_published_snapshot_content_digest",
        ],
        optional: []
    ),
    .init(
        filename: "activation-receipt.schema.json",
        required: [
            "schema_version", "activation_id", "transaction_id", "target_canon_version", "target_product_version",
            "overlay_id", "overlay_digest", "integration_approval", "approval_source_artifact_id",
            "approval_source_artifact_digest", "approval_sidecar_relative_path", "approval_sidecar_digest",
            "approval_timestamp", "base_snapshot_content_digest", "published_snapshot_content_digest",
            "digest_transitions",
        ],
        optional: []
    ),
    .init(
        filename: "exception.schema.json",
        required: [
            "schema_version", "id", "rule_id", "exact_scope", "reason", "risk_class", "compensating_controls",
            "owner_principal_id", "owner_actor_id", "owner_role_id", "approver_principal_id", "approver_actor_id",
            "approver_role_id", "expires_at", "affected_artifact_digest", "removal_plan",
        ],
        optional: []
    ),
    .init(
        filename: "derived-registration-delta.schema.json",
        required: [
            "schema_version", "delta_id", "owner_role_id", "base_snapshot_content_digest", "entries", "delta_digest",
        ],
        optional: []
    ),
]

private func requiredNames(in schema: [String: Any]) -> [String]? {
    schema["required"] as? [String]
}

private func integerValue(_ value: Any?) -> Int? {
    guard let number = value as? NSNumber,
          String(cString: number.objCType) != "c",
          number.doubleValue.rounded(.towardZero) == number.doubleValue
    else { return nil }
    return number.intValue
}

private func isInteger(_ value: Any?, equalTo expected: Int) -> Bool {
    integerValue(value) == expected
}

private func matches(pattern: String, _ value: String) -> Bool {
    guard let expression = try? NSRegularExpression(pattern: pattern) else { return false }
    let range = NSRange(value.startIndex ..< value.endIndex, in: value)
    return expression.firstMatch(in: value, range: range) != nil
}

private func resolvedSchema(_ schema: [String: Any], root: [String: Any]) -> [String: Any]? {
    guard let reference = schema["$ref"] as? String else { return schema }
    return resolve(reference: reference, in: root) as? [String: Any]
}

private func resolve(reference: String, in root: [String: Any]) -> Any? {
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

private func propertySchemas(
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

private func stringConstants(for property: String, in schema: [String: Any], root: [String: Any]) -> [String] {
    let values = propertySchemas(for: property, in: schema, root: root).compactMap { propertySchema -> String? in
        let resolved = resolvedSchema(propertySchema, root: root) ?? propertySchema
        return resolved["const"] as? String
    }
    return Array(Set(values)).sorted()
}

private func stringVocabulary(
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

private func findStringEnum(named name: String, in value: Any) -> [String]? {
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

private func findConditional(
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

private func namedSchemaNodes(in root: [String: Any]) -> [NamedSchemaNode] {
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

private func isCanonicalPathNode(_ name: String) -> Bool {
    name.hasSuffix("_path") || [
        "canonical_relative_path",
        "exact_relative_path",
        "relative_path",
        "target_path",
    ].contains(name)
}

private func isCanonicalTimestampNode(_ name: String) -> Bool {
    name == "canonical_timestamp" || name.hasSuffix("_timestamp") || name.hasSuffix("_at")
}

private func isCanonicalDateNode(_ name: String) -> Bool {
    name == "canonical_date" || name.hasSuffix("_date")
}

private func assertFormatMarker(_ schema: [String: Any], format: String, context: String) {
    #expect(schema["format"] as? String == format, "\(context) must declare format \(format)")
    #expect(
        schema["x-ifl-format-assertion-required"] as? Bool == true,
        "\(context) must require runtime custom-format assertion"
    )
}

private func schemaAccepts(_ instance: Any, against schema: [String: Any], root: [String: Any]) -> Bool {
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

private func jsonTypeMatches(_ value: Any, type: String) -> Bool {
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

private func jsonEquivalent(_ lhs: Any, _ rhs: Any) -> Bool {
    guard JSONSerialization.isValidJSONObject([lhs]), JSONSerialization.isValidJSONObject([rhs]),
          let left = try? JSONSerialization.data(withJSONObject: [lhs], options: [.sortedKeys]),
          let right = try? JSONSerialization.data(withJSONObject: [rhs], options: [.sortedKeys])
    else { return false }
    return left == right
}

private func declaredSchemaIDs(in value: Any) -> [String] {
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

private func contractProblems(
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

private func resolves(reference: String, in root: [String: Any]) -> Bool {
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
