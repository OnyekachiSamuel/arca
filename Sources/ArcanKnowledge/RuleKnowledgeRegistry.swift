import Foundation

public struct RuleKnowledgeRegistry: RuleKnowledgeProviding {
    public static let currentSchemaVersion = 1

    private let knowledgeByRuleID: [String: RuleKnowledge]

    public init(data: Data) throws {
        let document: RuleKnowledgeDocument

        do {
            document = try JSONDecoder().decode(
                RuleKnowledgeDocument.self,
                from: data
            )
        } catch {
            throw RuleKnowledgeRegistryError.invalidJSON
        }

        guard document.schemaVersion == Self.currentSchemaVersion else {
            throw RuleKnowledgeRegistryError.unsupportedSchemaVersion(
                document.schemaVersion
            )
        }

        guard !document.rules.isEmpty else {
            throw RuleKnowledgeRegistryError.emptyRegistry
        }

        var indexedKnowledge: [String: RuleKnowledge] = [:]

        for knowledge in document.rules {
            try Self.validate(knowledge)

            guard indexedKnowledge[knowledge.ruleID] == nil else {
                throw RuleKnowledgeRegistryError.duplicateRuleID(
                    knowledge.ruleID
                )
            }

            indexedKnowledge[knowledge.ruleID] = knowledge
        }

        knowledgeByRuleID = indexedKnowledge
    }

    public static func bundled() throws -> RuleKnowledgeRegistry {
        guard let resourceURL = Bundle.module.url(
            forResource: "rule-knowledge",
            withExtension: "json"
        ) else {
            throw RuleKnowledgeRegistryError.bundledResourceNotFound
        }

        let data: Data

        do {
            data = try Data(contentsOf: resourceURL)
        } catch {
            throw RuleKnowledgeRegistryError.unreadableResource
        }

        return try RuleKnowledgeRegistry(data: data)
    }

    public func knowledge(for ruleID: String) -> RuleKnowledge? {
        knowledgeByRuleID[ruleID]
    }

    private static func validate(_ knowledge: RuleKnowledge) throws {
        guard !knowledge.ruleID.trimmed.isEmpty else {
            throw invalidRule(knowledge, reason: "rule ID must not be empty.")
        }

        guard knowledge.ruleID == knowledge.ruleID.trimmed else {
            throw invalidRule(
                knowledge,
                reason: "rule ID must not contain surrounding whitespace."
            )
        }

        guard !knowledge.title.trimmed.isEmpty else {
            throw invalidRule(knowledge, reason: "title must not be empty.")
        }

        guard !knowledge.definition.trimmed.isEmpty else {
            throw invalidRule(
                knowledge,
                reason: "definition must not be empty."
            )
        }

        guard !knowledge.evidenceCriteria.isEmpty else {
            throw invalidRule(
                knowledge,
                reason: "must contain at least one evidence criterion."
            )
        }

        guard knowledge.evidenceCriteria.allSatisfy({
            !$0.trimmed.isEmpty
        }) else {
            throw invalidRule(
                knowledge,
                reason: "evidence criteria must not contain empty values."
            )
        }

        guard !knowledge.refactoringGuardrails.isEmpty else {
            throw invalidRule(
                knowledge,
                reason: "must contain at least one refactoring guardrail."
            )
        }

        guard knowledge.refactoringGuardrails.allSatisfy({
            !$0.trimmed.isEmpty
        }) else {
            throw invalidRule(
                knowledge,
                reason: "refactoring guardrails must not contain empty values."
            )
        }
    }

    private static func invalidRule(
        _ knowledge: RuleKnowledge,
        reason: String
    ) -> RuleKnowledgeRegistryError {
        .invalidRule(ruleID: knowledge.ruleID, reason: reason)
    }
}

private struct RuleKnowledgeDocument: Decodable {
    let schemaVersion: Int
    let rules: [RuleKnowledge]
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
