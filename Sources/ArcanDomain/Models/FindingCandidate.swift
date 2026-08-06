import Foundation

public struct FindingCandidate:
    Codable,
    Equatable,
    Sendable,
    Identifiable
{
    public let candidateID: UUID
    public let ruleID: String
    public let title: String
    public let explanation: String
    public let filePath: String
    public let range: SourceRange?
    public let proposedSeverity: Severity
    public let proposedCategory: FindingCategory
    public let evidence: [FindingEvidence]
    public let sourceIdentifiers: [String]
    public let analyzerMetadata: [String: FindingMetadataValue]

    public var id: UUID {
        candidateID
    }

    public init(
        candidateID: UUID,
        ruleID: String,
        title: String,
        explanation: String,
        filePath: String,
        range: SourceRange?,
        proposedSeverity: Severity,
        proposedCategory: FindingCategory,
        evidence: [FindingEvidence],
        sourceIdentifiers: [String],
        analyzerMetadata: [String: FindingMetadataValue] = [:]
    ) throws {
        guard !ruleID.isBlank else {
            throw FindingCandidateValidationError.missingRuleID
        }
        guard !title.isBlank else {
            throw FindingCandidateValidationError.missingTitle
        }
        guard !explanation.isBlank else {
            throw FindingCandidateValidationError.missingExplanation
        }
        guard !filePath.isBlank else {
            throw FindingCandidateValidationError.missingFilePath
        }
        guard range.map(Self.isValid) ?? true else {
            throw FindingCandidateValidationError.invalidSourceRange
        }
        guard !evidence.isEmpty else {
            throw FindingCandidateValidationError.missingEvidence
        }
        guard evidence.allSatisfy(Self.hasValidSourceRange) else {
            throw FindingCandidateValidationError.invalidEvidenceSourceRange
        }
        guard !sourceIdentifiers.isEmpty else {
            throw FindingCandidateValidationError.missingSourceIdentifiers
        }
        guard sourceIdentifiers.allSatisfy({ !$0.isBlank }) else {
            throw FindingCandidateValidationError.blankSourceIdentifier
        }

        self.candidateID = candidateID
        self.ruleID = ruleID
        self.title = title
        self.explanation = explanation
        self.filePath = filePath
        self.range = range
        self.proposedSeverity = proposedSeverity
        self.proposedCategory = proposedCategory
        self.evidence = evidence
        self.sourceIdentifiers = sourceIdentifiers
        self.analyzerMetadata = analyzerMetadata
    }

    private enum CodingKeys: String, CodingKey {
        case candidateID
        case ruleID
        case title
        case explanation
        case filePath
        case range
        case proposedSeverity
        case proposedCategory
        case evidence
        case sourceIdentifiers
        case analyzerMetadata
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        try self.init(
            candidateID: container.decode(
                UUID.self,
                forKey: .candidateID
            ),
            ruleID: container.decode(String.self, forKey: .ruleID),
            title: container.decode(String.self, forKey: .title),
            explanation: container.decode(
                String.self,
                forKey: .explanation
            ),
            filePath: container.decode(String.self, forKey: .filePath),
            range: container.decodeIfPresent(
                SourceRange.self,
                forKey: .range
            ),
            proposedSeverity: container.decode(
                Severity.self,
                forKey: .proposedSeverity
            ),
            proposedCategory: container.decode(
                FindingCategory.self,
                forKey: .proposedCategory
            ),
            evidence: container.decode(
                [FindingEvidence].self,
                forKey: .evidence
            ),
            sourceIdentifiers: container.decode(
                [String].self,
                forKey: .sourceIdentifiers
            ),
            analyzerMetadata: container.decodeIfPresent(
                [String: FindingMetadataValue].self,
                forKey: .analyzerMetadata
            ) ?? [:]
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(candidateID, forKey: .candidateID)
        try container.encode(ruleID, forKey: .ruleID)
        try container.encode(title, forKey: .title)
        try container.encode(explanation, forKey: .explanation)
        try container.encode(filePath, forKey: .filePath)
        try container.encodeIfPresent(range, forKey: .range)
        try container.encode(proposedSeverity, forKey: .proposedSeverity)
        try container.encode(proposedCategory, forKey: .proposedCategory)
        try container.encode(evidence, forKey: .evidence)
        try container.encode(sourceIdentifiers, forKey: .sourceIdentifiers)
        try container.encode(analyzerMetadata, forKey: .analyzerMetadata)
    }

    private static func hasValidSourceRange(
        _ evidence: FindingEvidence
    ) -> Bool {
        switch evidence {
        case .metric, .ratio:
            true
        case .analyzer(let analyzerEvidence):
            analyzerEvidence.range.map(isValid) ?? true
        case .sourceCode(let sourceCodeEvidence):
            isValid(sourceCodeEvidence.range)
        }
    }

    private static func isValid(_ range: SourceRange) -> Bool {
        let positionsAreOneBased = range.startLine > 0
            && range.startColumn > 0
            && range.endLine > 0
            && range.endColumn > 0
        let endFollowsStart = range.endLine > range.startLine
            || (
                range.endLine == range.startLine
                    && range.endColumn >= range.startColumn
            )

        return positionsAreOneBased && endFollowsStart
    }
}

private extension String {
    var isBlank: Bool {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
