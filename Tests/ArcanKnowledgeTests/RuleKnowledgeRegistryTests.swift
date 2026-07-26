import ArcanDomain
import ArcanKnowledge
import Foundation
import Testing

@Suite("Rule knowledge registry")
struct RuleKnowledgeRegistryTests {
    @Test("returns bundled guidance for the God Object rule")
    func returnsGodObjectKnowledge() throws {
        let registry = try RuleKnowledgeRegistry.bundled()

        #expect(
            registry.allKnowledge.map(\.ruleID) == [
                "ARCAN-GOD-001",
                "ARCAN-FEATURE-ENVY-001",
                "ARCAN-LONG-METHOD-001",
                "ARCAN-STYLE-001"
            ]
        )

        let knowledge = try #require(
            registry.knowledge(for: "ARCAN-GOD-001")
        )

        #expect(knowledge.ruleID == "ARCAN-GOD-001")
        #expect(knowledge.title == "God Object candidate")
        #expect(knowledge.group == .codeSmellsAndAntiPatterns)
        #expect(knowledge.category == .antiPattern)
        #expect(knowledge.defaultSeverity == .warning)
        #expect(
            knowledge.definition
                == "A God Object candidate is a type that centralizes multiple unrelated responsibilities and exceeds multiple configured structural thresholds."
        )
        #expect(
            knowledge.evidenceCriteria == [
                "The type exceeds at least the configured minimum number of structural signals.",
                "Its declaration line count exceeds the configured line threshold.",
                "Its method count exceeds the configured method threshold.",
                "Its stored-property count exceeds the configured property threshold."
            ]
        )
        #expect(
            knowledge.classificationGuidance == [
                "Require evidence of multiple responsibilities or multiple structural signals.",
                "Do not classify a type as a God Object based on line count alone.",
                "Distinguish a deliberately thin coordinator or facade from a type that owns unrelated business responsibilities."
            ]
        )
        #expect(
            knowledge.severityGuidance == [
                "Use warning when the type exceeds multiple configured structural thresholds.",
                "Increase severity only when broad coupling or unrelated responsibilities create a substantial maintenance risk."
            ]
        )
        #expect(
            knowledge.refactoringGuardrails == [
                "Group properties and methods by responsibility.",
                "Extract each responsibility into a dedicated type.",
                "Keep only necessary coordination in the original type."
            ]
        )
    }

    @Test("returns no guidance for unknown or differently cased rule IDs")
    func returnsNilForUnknownRuleID() throws {
        let registry = try RuleKnowledgeRegistry.bundled()

        #expect(registry.knowledge(for: "ARCAN-UNKNOWN-001") == nil)
        #expect(registry.knowledge(for: "arcan-god-001") == nil)
    }

    @Test("conforms to the provider-independent lookup contract")
    func conformsToProviderContract() throws {
        let provider: any RuleKnowledgeProviding =
            try RuleKnowledgeRegistry.bundled()

        #expect(provider.knowledge(for: "ARCAN-GOD-001") != nil)
        #expect(provider.allKnowledge.count == 4)
        #expect(
            provider.knowledge(in: .codeSmellsAndAntiPatterns).count == 3
        )
    }

    @Test("returns rules by group in resource order")
    func returnsRulesByGroup() throws {
        let data = try makeDocument(
            rules: [
                makeRule(
                    ruleID: "ARCAN-GOD-001",
                    title: "God Object candidate",
                    group: "codeSmellsAndAntiPatterns",
                    category: "antiPattern"
                ),
                makeRule(
                    ruleID: "ARCAN-TCA-001",
                    title: "TCA rule",
                    group: "tcaArchitecture",
                    category: "architecture"
                ),
                makeRule(
                    ruleID: "ARCAN-LONG-METHOD-001",
                    title: "Long Method candidate",
                    group: "codeSmellsAndAntiPatterns",
                    category: "antiPattern"
                ),
                makeRule(
                    ruleID: "ARCAN-TEAM-001",
                    title: "Team convention",
                    group: "teamConventions",
                    category: "teamConvention"
                ),
                makeRule(
                    ruleID: "ARCAN-STYLE-001",
                    title: "Style rule",
                    group: "style",
                    category: "style"
                )
            ]
        )
        let registry = try RuleKnowledgeRegistry(data: data)

        #expect(
            registry.allKnowledge.map(\.ruleID) == [
                "ARCAN-GOD-001",
                "ARCAN-TCA-001",
                "ARCAN-LONG-METHOD-001",
                "ARCAN-TEAM-001",
                "ARCAN-STYLE-001"
            ]
        )
        #expect(
            registry.knowledge(in: .codeSmellsAndAntiPatterns)
                .map(\.ruleID) == [
                    "ARCAN-GOD-001",
                    "ARCAN-LONG-METHOD-001"
                ]
        )
        #expect(
            registry.knowledge(in: .tcaArchitecture)
                .map(\.ruleID) == ["ARCAN-TCA-001"]
        )
        #expect(
            registry.knowledge(in: .teamConventions)
                .map(\.ruleID) == ["ARCAN-TEAM-001"]
        )
        #expect(
            registry.knowledge(in: .style)
                .map(\.ruleID) == ["ARCAN-STYLE-001"]
        )
    }

    @Test("rejects an unsupported knowledge schema version")
    func rejectsUnsupportedSchemaVersion() throws {
        let data = try makeDocument(schemaVersion: 3)

        expectLoadingError(
            .unsupportedSchemaVersion(3),
            whenLoading: data
        )
    }

    @Test("rejects duplicate rule identifiers")
    func rejectsDuplicateRuleIDs() throws {
        let rule = makeRule()
        let data = try makeDocument(rules: [rule, rule])

        expectLoadingError(
            .duplicateRuleID("ARCAN-GOD-001"),
            whenLoading: data
        )
    }

    @Test("rejects rules without evidence criteria")
    func rejectsMissingEvidenceCriteria() throws {
        let data = try makeDocument(
            rules: [makeRule(evidenceCriteria: [])]
        )

        expectLoadingError(
            .invalidRule(
                ruleID: "ARCAN-GOD-001",
                reason: "must contain at least one evidence criterion."
            ),
            whenLoading: data
        )
    }

    @Test("rejects rules without classification guidance")
    func rejectsMissingClassificationGuidance() throws {
        let data = try makeDocument(
            rules: [makeRule(classificationGuidance: [])]
        )

        expectLoadingError(
            .invalidRule(
                ruleID: "ARCAN-GOD-001",
                reason: "must contain at least one classification guidance item."
            ),
            whenLoading: data
        )
    }

    @Test("rejects rules without severity guidance")
    func rejectsMissingSeverityGuidance() throws {
        let data = try makeDocument(
            rules: [makeRule(severityGuidance: [])]
        )

        expectLoadingError(
            .invalidRule(
                ruleID: "ARCAN-GOD-001",
                reason: "must contain at least one severity guidance item."
            ),
            whenLoading: data
        )
    }

    @Test("rejects a category that does not match its rule group")
    func rejectsMismatchedGroupAndCategory() throws {
        let data = try makeDocument(
            rules: [
                makeRule(
                    group: "tcaArchitecture",
                    category: "antiPattern"
                )
            ]
        )

        expectLoadingError(
            .invalidRule(
                ruleID: "ARCAN-GOD-001",
                reason: "category 'antiPattern' does not match group 'tcaArchitecture'."
            ),
            whenLoading: data
        )
    }

    @Test("rejects malformed JSON")
    func rejectsMalformedJSON() {
        expectLoadingError(
            .invalidJSON,
            whenLoading: Data("not JSON".utf8)
        )
    }

    private func makeDocument(
        schemaVersion: Int = 2,
        rules: [[String: Any]]? = nil
    ) throws -> Data {
        try JSONSerialization.data(
            withJSONObject: [
                "schemaVersion": schemaVersion,
                "rules": rules ?? [makeRule()]
            ]
        )
    }

    private func makeRule(
        ruleID: String = "ARCAN-GOD-001",
        title: String = "God Object candidate",
        group: String = "codeSmellsAndAntiPatterns",
        category: String = "antiPattern",
        evidenceCriteria: [String] = ["A structural threshold is exceeded."],
        classificationGuidance: [String] = [
            "Require evidence of multiple responsibilities."
        ],
        severityGuidance: [String] = [
            "Use warning when multiple signals are present."
        ]
    ) -> [String: Any] {
        [
            "ruleID": ruleID,
            "title": title,
            "group": group,
            "category": category,
            "defaultSeverity": "warning",
            "definition": "A type has accumulated too many responsibilities.",
            "evidenceCriteria": evidenceCriteria,
            "classificationGuidance": classificationGuidance,
            "severityGuidance": severityGuidance,
            "refactoringGuardrails": ["Extract focused types."]
        ]
    }

    private func expectLoadingError(
        _ expectedError: RuleKnowledgeRegistryError,
        whenLoading data: Data,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        do {
            _ = try RuleKnowledgeRegistry(data: data)
            Issue.record(
                "Expected loading to fail with \(expectedError).",
                sourceLocation: sourceLocation
            )
        } catch let error as RuleKnowledgeRegistryError {
            #expect(error == expectedError, sourceLocation: sourceLocation)
        } catch {
            Issue.record(
                "Expected RuleKnowledgeRegistryError, got \(error).",
                sourceLocation: sourceLocation
            )
        }
    }
}
