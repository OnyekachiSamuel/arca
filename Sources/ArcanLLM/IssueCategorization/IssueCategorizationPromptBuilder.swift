import ArcanDomain
import ArcanKnowledge
import Foundation

public struct IssueCategorizationPromptBuilder: Sendable {
    private let limits: IssueCategorizationPromptLimits

    public init(
        limits: IssueCategorizationPromptLimits = .default
    ) {
        self.limits = limits
    }

    public func build(
        candidates: [FindingCandidate],
        ruleKnowledge: [RuleKnowledge]
    ) throws -> IssueCategorizationPrompt {
        guard limits.maximumPromptUTF8Bytes > 0 else {
            throw IssueCategorizationPromptBuildingError.invalidLimits
        }
        guard !candidates.isEmpty else {
            throw IssueCategorizationPromptBuildingError.noCandidates
        }
        guard !ruleKnowledge.isEmpty else {
            throw IssueCategorizationPromptBuildingError.noRuleKnowledge
        }

        try validateCandidateIDs(candidates)
        let sortedKnowledge = try validatedKnowledge(ruleKnowledge)
        let categories = FindingCategory.allCases.filter {
            $0 != .uncategorized
        }
        let assessments = FindingAssessment.allCases
        let payload = IssueCategorizationPromptInput(
            candidates: candidates.map(makeCandidateInput),
            ruleKnowledge: sortedKnowledge.map(makeRuleInput),
            allowedCategories: categories,
            allowedAssessments: assessments
        )
        let inputJSON = try encode(payload)
        let promptText = IssueCategorizationPromptTemplateV1.render(
            inputJSON: inputJSON,
            candidateIDs: candidates.map { $0.candidateID.uuidString },
            categories: categories,
            assessments: assessments
        )
        let byteCount = promptText.utf8.count

        guard byteCount <= limits.maximumPromptUTF8Bytes else {
            throw IssueCategorizationPromptBuildingError.promptTooLarge(
                actualBytes: byteCount,
                maximumBytes: limits.maximumPromptUTF8Bytes
            )
        }

        return IssueCategorizationPrompt(
            templateID: IssueCategorizationPromptTemplateV1.id,
            templateVersion: IssueCategorizationPromptTemplateV1.version,
            text: promptText
        )
    }

    private func validateCandidateIDs(
        _ candidates: [FindingCandidate]
    ) throws {
        var encountered: Set<UUID> = []
        for candidate in candidates {
            guard encountered.insert(candidate.candidateID).inserted else {
                throw IssueCategorizationPromptBuildingError
                    .duplicateCandidateID(candidate.candidateID.uuidString)
            }
        }
    }

    private func validatedKnowledge(
        _ knowledge: [RuleKnowledge]
    ) throws -> [RuleKnowledge] {
        var encountered: Set<String> = []
        for rule in knowledge {
            guard encountered.insert(rule.ruleID).inserted else {
                throw IssueCategorizationPromptBuildingError
                    .duplicateRuleID(rule.ruleID)
            }
        }
        return knowledge.sorted { $0.ruleID < $1.ruleID }
    }

    private func makeCandidateInput(
        _ candidate: FindingCandidate
    ) -> IssueCategorizationCandidateInput {
        IssueCategorizationCandidateInput(
            candidateID: candidate.candidateID,
            analyzerSources: candidate.sourceIdentifiers,
            ruleID: candidate.ruleID,
            title: candidate.title,
            path: candidate.filePath,
            range: candidate.range,
            severity: candidate.proposedSeverity,
            preliminaryCategory: candidate.proposedCategory,
            evidence: candidate.evidence.map(redactedEvidence),
            explanation: PromptTextRedactor.redactCommonSecrets(
                in: candidate.explanation
            )
        )
    }

    private func redactedEvidence(
        _ evidence: FindingEvidence
    ) -> FindingEvidence {
        switch evidence {
        case .metric, .ratio:
            evidence
        case .analyzer(let value):
            .analyzer(AnalyzerEvidence(
                description: PromptTextRedactor.redactCommonSecrets(
                    in: value.description
                ),
                externalRuleID: value.externalRuleID,
                range: value.range
            ))
        case .sourceCode(let value):
            .sourceCode(SourceCodeEvidence(
                description: PromptTextRedactor.redactCommonSecrets(
                    in: value.description
                ),
                range: value.range,
                excerpt: PromptTextRedactor.redactCommonSecrets(
                    in: value.excerpt
                )
            ))
        }
    }

    private func makeRuleInput(
        _ knowledge: RuleKnowledge
    ) -> IssueCategorizationRuleInput {
        IssueCategorizationRuleInput(
            ruleID: knowledge.ruleID,
            title: knowledge.title,
            group: knowledge.group,
            category: knowledge.category,
            defaultSeverity: knowledge.defaultSeverity,
            definition: knowledge.definition,
            evidenceCriteria: knowledge.evidenceCriteria,
            classificationGuidance: knowledge.classificationGuidance,
            severityGuidance: knowledge.severityGuidance
        )
    }

    private func encode(
        _ input: IssueCategorizationPromptInput
    ) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [
            .prettyPrinted,
            .sortedKeys,
            .withoutEscapingSlashes
        ]
        do {
            return String(decoding: try encoder.encode(input), as: UTF8.self)
        } catch {
            throw IssueCategorizationPromptBuildingError.inputEncodingFailed
        }
    }
}

private struct IssueCategorizationPromptInput: Encodable {
    let candidates: [IssueCategorizationCandidateInput]
    let ruleKnowledge: [IssueCategorizationRuleInput]
    let allowedCategories: [FindingCategory]
    let allowedAssessments: [FindingAssessment]
}

private struct IssueCategorizationCandidateInput: Encodable {
    let candidateID: UUID
    let analyzerSources: [String]
    let ruleID: String
    let title: String
    let path: String
    let range: SourceRange?
    let severity: Severity
    let preliminaryCategory: FindingCategory
    let evidence: [FindingEvidence]
    let explanation: String
}

private struct IssueCategorizationRuleInput: Encodable {
    let ruleID: String
    let title: String
    let group: RuleKnowledgeGroup
    let category: FindingCategory
    let defaultSeverity: Severity
    let definition: String
    let evidenceCriteria: [String]
    let classificationGuidance: [String]
    let severityGuidance: [String]
}
