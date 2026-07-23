import ArcanDomain
import ArcanKnowledge
import Foundation
import Testing

@Suite("Rule knowledge registry")
struct RuleKnowledgeRegistryTests {
    @Test("returns bundled guidance for the God Object rule")
    func returnsGodObjectKnowledge() throws {
        let registry = try RuleKnowledgeRegistry.bundled()

        let knowledge = try #require(
            registry.knowledge(for: "ARCAN-GOD-001")
        )

        #expect(knowledge.ruleID == "ARCAN-GOD-001")
        #expect(knowledge.title == "God Object candidate")
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
    }

    @Test("rejects an unsupported knowledge schema version")
    func rejectsUnsupportedSchemaVersion() throws {
        let data = try makeDocument(schemaVersion: 2)

        expectLoadingError(
            .unsupportedSchemaVersion(2),
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

    @Test("rejects malformed JSON")
    func rejectsMalformedJSON() {
        expectLoadingError(
            .invalidJSON,
            whenLoading: Data("not JSON".utf8)
        )
    }

    private func makeDocument(
        schemaVersion: Int = 1,
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
        evidenceCriteria: [String] = ["A structural threshold is exceeded."]
    ) -> [String: Any] {
        [
            "ruleID": "ARCAN-GOD-001",
            "title": "God Object candidate",
            "category": "antiPattern",
            "defaultSeverity": "warning",
            "definition": "A type has accumulated too many responsibilities.",
            "evidenceCriteria": evidenceCriteria,
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
