import ArcaDomain
import ArcaKnowledge
import Foundation

public struct CodeAnalysisResponseParser: Sendable {
    private let knowledgeByRuleID: [String: RuleKnowledge]
    private let core: CodeAnalysisResponseParserCore
    
    public init(
        rules: [RuleKnowledge],
        limits: CodeAnalysisResponseLimits = .default
    ) {
        knowledgeByRuleID = Dictionary(
            rules.map { ($0.ruleID, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        core = CodeAnalysisResponseParserCore(limits: limits)
    }
    
    public func parse(
        _ responseText: String,
        context: SourceFileAnalysisContext
    ) -> CodeAnalysisResponseParsingResult {
        guard !knowledgeByRuleID.isEmpty else {
            return core.rejected(
                code: "ARCA-LLM-ANALYSIS-INVALID-CONFIGURATION",
                message: "Guided analysis requires at least one rule."
            )
        }
        
        return core.parse(
            responseText,
            context: context,
            schemaErrorMessage: "The LLM code-analysis response does not match the required schema.",
            decodeFindings: {
                try JSONDecoder().decode(
                    GuidedCodeAnalysisResponse.self,
                    from: $0
                ).findings
            },
            resolve: { finding, findingIndex in
                guard let knowledge = knowledgeByRuleID[finding.ruleID] else {
                    return .rejected(
                        codeAnalysisDiagnostic(
                            code: "ARCA-LLM-ANALYSIS-UNKNOWN-RULE",
                            message: "Finding \(findingIndex + 1) references unknown rule ID '\(finding.ruleID)'."
                        ))
                }
                return .accepted(
                    ResolvedCodeAnalysisFinding(
                        ruleID: knowledge.ruleID,
                        title: knowledge.title,
                        explanation: finding.explanation,
                        evidence: finding.evidence
                    ))
            }
        )
    }
}

private struct GuidedCodeAnalysisResponse: Decodable {
    let findings: [GuidedCodeAnalysisFindingResponse]
    
    private enum CodingKeys: String, CodingKey, CaseIterable { case findings }
    
    init(from decoder: any Decoder) throws {
        try rejectUnknownResponseKeys(
            Set(CodingKeys.allCases.map(\.rawValue)),
            from: decoder
        )
        findings = try decoder.container(keyedBy: CodingKeys.self).decode(
            [GuidedCodeAnalysisFindingResponse].self,
            forKey: .findings
        )
    }
}

private struct GuidedCodeAnalysisFindingResponse: Decodable {
    let ruleID: String
    let explanation: String
    let evidence: [CodeAnalysisEvidenceResponse]
    
    private enum CodingKeys: String, CodingKey, CaseIterable {
        case ruleID
        case explanation
        case evidence
    }
    
    init(from decoder: any Decoder) throws {
        try rejectUnknownResponseKeys(
            Set(CodingKeys.allCases.map(\.rawValue)),
            from: decoder
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        ruleID = try container.decode(String.self, forKey: .ruleID)
        explanation = try container.decode(String.self, forKey: .explanation)
        evidence = try container.decode(
            [CodeAnalysisEvidenceResponse].self,
            forKey: .evidence
        )
    }
}
