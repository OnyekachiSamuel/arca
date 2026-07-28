import ArcanDomain
import Foundation

public struct IssueCategorizationResponseParser: Sendable {
    private let limits: IssueCategorizationResponseLimits

    public init(
        limits: IssueCategorizationResponseLimits = .default
    ) {
        self.limits = limits
    }

    public func parse(
        _ responseText: String,
        candidates: [FindingCandidate],
        allowedRuleIDs: Set<String>
    ) -> IssueCategorizationParsingResult {
        guard limits.isValid,
              !candidates.isEmpty,
              Set(candidates.map(\.candidateID)).count == candidates.count,
              !allowedRuleIDs.isEmpty,
              allowedRuleIDs.allSatisfy({ !$0.trimmed.isEmpty }) else {
            return rejected(
                code: "ARCAN-LLM-CATEGORIZATION-INVALID-CONFIGURATION",
                message: "Issue-categorization parser inputs and limits must be valid."
            )
        }
        guard responseText.utf8.count <= limits.maximumResponseUTF8Bytes else {
            return rejected(
                code: "ARCAN-LLM-CATEGORIZATION-RESPONSE-TOO-LARGE",
                message: "The issue-categorization response exceeds the maximum size."
            )
        }
        guard let jsonText = LLMJSONDocumentExtractor.extract(
            from: responseText
        ), let data = jsonText.data(using: .utf8) else {
            return invalidJSON()
        }

        do {
            _ = try JSONSerialization.jsonObject(with: data)
        } catch {
            return invalidJSON()
        }

        let response: IssueCategorizationResponse
        do {
            response = try JSONDecoder().decode(
                IssueCategorizationResponse.self,
                from: data
            )
        } catch {
            return rejected(
                code: "ARCAN-LLM-CATEGORIZATION-INVALID-SCHEMA",
                message: "The issue-categorization response does not match the required schema."
            )
        }

        let summary = response.summary.trimmed
        guard !summary.isEmpty,
              summary.utf8.count <= limits.maximumSummaryUTF8Bytes else {
            return rejected(
                code: "ARCAN-LLM-CATEGORIZATION-INVALID-SUMMARY",
                message: "The categorization summary is empty or exceeds the maximum size."
            )
        }
        guard !response.decisions.isEmpty,
              response.decisions.count <= limits.maximumDecisionCount else {
            return rejected(
                code: "ARCAN-LLM-CATEGORIZATION-INVALID-DECISION",
                message: "The response must contain a bounded decision list."
            )
        }

        let suppliedIDs = Set(candidates.map(\.candidateID))
        let candidatesByID = Dictionary(
            uniqueKeysWithValues: candidates.map { ($0.candidateID, $0) }
        )
        var referencedIDs: Set<UUID> = []
        var decisions: [FindingCategorizationDecision] = []

        for (index, decision) in response.decisions.enumerated() {
            guard !decision.candidateIDs.isEmpty,
                  decision.candidateIDs.count
                    <= limits.maximumCandidateIDsPerDecision else {
                return invalidDecision(
                    index,
                    reason: "has an empty or oversized candidate group"
                )
            }

            var groupIDs: Set<UUID> = []
            for candidateID in decision.candidateIDs {
                guard suppliedIDs.contains(candidateID) else {
                    return rejected(
                        code: "ARCAN-LLM-CATEGORIZATION-UNKNOWN-CANDIDATE",
                        message: "Decision \(index) references unknown candidate ID '\(candidateID.uuidString)'."
                    )
                }
                guard groupIDs.insert(candidateID).inserted,
                      referencedIDs.insert(candidateID).inserted else {
                    return rejected(
                        code: "ARCAN-LLM-CATEGORIZATION-DUPLICATE-CANDIDATE",
                        message: "Candidate ID '\(candidateID.uuidString)' is assigned more than once."
                    )
                }
            }

            guard decision.category != .uncategorized else {
                return invalidDecision(
                    index,
                    reason: "uses the unsupported uncategorized category"
                )
            }
            let canonicalRuleID = decision.canonicalRuleID.trimmed
            guard allowedRuleIDs.contains(canonicalRuleID) else {
                return rejected(
                    code: "ARCAN-LLM-CATEGORIZATION-UNKNOWN-RULE",
                    message: "Decision \(index) references unknown canonical rule ID '\(canonicalRuleID)'."
                )
            }
            let title = decision.title.trimmed
            let rationale = decision.rationale.trimmed
            guard !title.isEmpty,
                  title.utf8.count <= limits.maximumTitleUTF8Bytes,
                  !rationale.isEmpty,
                  rationale.utf8.count <= limits.maximumRationaleUTF8Bytes else {
                return invalidDecision(
                    index,
                    reason: "has empty or oversized text"
                )
            }

            decisions.append(FindingCategorizationDecision(
                candidateIDs: decision.candidateIDs,
                sourceIdentifiers: sourceIdentifiers(
                    for: decision.candidateIDs,
                    candidatesByID: candidatesByID
                ),
                assessment: decision.assessment,
                category: decision.category,
                severity: decision.severity,
                canonicalRuleID: canonicalRuleID,
                title: title,
                rationale: rationale
            ))
        }

        let missingIDs = suppliedIDs.subtracting(referencedIDs)
        guard missingIDs.isEmpty else {
            let values = missingIDs.map(\.uuidString).sorted().joined(
                separator: ", "
            )
            return rejected(
                code: "ARCAN-LLM-CATEGORIZATION-MISSING-CANDIDATE",
                message: "The response does not assess candidate IDs: \(values)."
            )
        }

        return IssueCategorizationParsingResult(
            categorization: FindingCategorization(
                summary: summary,
                decisions: decisions
            ),
            diagnostics: []
        )
    }

    private func sourceIdentifiers(
        for candidateIDs: [UUID],
        candidatesByID: [UUID: FindingCandidate]
    ) -> [String] {
        var encountered: Set<String> = []
        return candidateIDs.flatMap {
            candidatesByID[$0]?.sourceIdentifiers ?? []
        }.filter { encountered.insert($0).inserted }
    }

    private func invalidJSON() -> IssueCategorizationParsingResult {
        rejected(
            code: "ARCAN-LLM-CATEGORIZATION-INVALID-JSON",
            message: "The issue-categorization response is not a supported JSON document."
        )
    }

    private func invalidDecision(
        _ index: Int,
        reason: String
    ) -> IssueCategorizationParsingResult {
        rejected(
            code: "ARCAN-LLM-CATEGORIZATION-INVALID-DECISION",
            message: "Decision \(index) \(reason)."
        )
    }

    private func rejected(
        code: String,
        message: String
    ) -> IssueCategorizationParsingResult {
        IssueCategorizationParsingResult(
            categorization: nil,
            diagnostics: [AnalyzerDiagnostic(
                code: code,
                severity: .warning,
                message: message
            )]
        )
    }
}

private struct IssueCategorizationResponse: Decodable {
    let summary: String
    let decisions: [IssueCategorizationDecisionResponse]

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case summary
        case decisions
    }

    init(from decoder: any Decoder) throws {
        try rejectCategorizationUnknownKeys(
            Set(CodingKeys.allCases.map(\.rawValue)),
            from: decoder
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        summary = try container.decode(String.self, forKey: .summary)
        decisions = try container.decode(
            [IssueCategorizationDecisionResponse].self,
            forKey: .decisions
        )
    }
}

private struct IssueCategorizationDecisionResponse: Decodable {
    let candidateIDs: [UUID]
    let assessment: FindingAssessment
    let category: FindingCategory
    let severity: Severity
    let canonicalRuleID: String
    let title: String
    let rationale: String

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case candidateIDs
        case assessment
        case category
        case severity
        case canonicalRuleID
        case title
        case rationale
    }

    init(from decoder: any Decoder) throws {
        try rejectCategorizationUnknownKeys(
            Set(CodingKeys.allCases.map(\.rawValue)),
            from: decoder
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        candidateIDs = try container.decode([UUID].self, forKey: .candidateIDs)
        assessment = try container.decode(
            FindingAssessment.self,
            forKey: .assessment
        )
        category = try container.decode(FindingCategory.self, forKey: .category)
        severity = try container.decode(Severity.self, forKey: .severity)
        canonicalRuleID = try container.decode(
            String.self,
            forKey: .canonicalRuleID
        )
        title = try container.decode(String.self, forKey: .title)
        rationale = try container.decode(String.self, forKey: .rationale)
    }
}

private struct CategorizationDynamicCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
        intValue = nil
    }

    init?(intValue: Int) {
        stringValue = String(intValue)
        self.intValue = intValue
    }
}

private func rejectCategorizationUnknownKeys(
    _ allowedKeys: Set<String>,
    from decoder: any Decoder
) throws {
    let container = try decoder.container(
        keyedBy: CategorizationDynamicCodingKey.self
    )
    let unknownKeys = container.allKeys.map(\.stringValue).filter {
        !allowedKeys.contains($0)
    }
    guard unknownKeys.isEmpty else {
        throw DecodingError.dataCorrupted(
            DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Unknown keys: \(unknownKeys.sorted())"
            )
        )
    }
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
