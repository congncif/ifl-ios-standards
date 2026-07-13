import Testing

extension CanonSchemaFileTests {
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
}

struct StringWitnessCorpus {
    let accepted: [String]
    let rejected: [String]
}

struct CompatibilitySelectorExpectation {
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

let compatibilitySubjects: Set<String> = [
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

let compatibilitySelectorKinds: Set<String> = [
    "bounded_range",
    "exact",
]

let compatibilityVersionSchemes: Set<String> = [
    "deployment_target",
    "identifier",
    "numeric_dotted",
    "semver",
    "swift_language_mode",
]

let compatibilitySelectorExpectations: [CompatibilitySelectorExpectation] = [
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

let semanticVersionWitnesses = StringWitnessCorpus(
    accepted: ["0.0.0", "1.0.0", "1.0.0-rc.1", "1.2.3+build.5"],
    rejected: ["1", "1.0", "01.0.0", "1.0.0-01", "latest", " 1.0.0", "1.0.0\n"]
)
