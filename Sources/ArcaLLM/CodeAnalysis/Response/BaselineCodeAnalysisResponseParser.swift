import ArcaDomain
import Foundation

public struct BaselineCodeAnalysisResponseParser: Sendable {
    private let core: CodeAnalysisResponseParserCore
    
    public init(limits: CodeAnalysisResponseLimits = .default) {
        core = CodeAnalysisResponseParserCore(limits: limits)
    }
    
    public func parse(
        _ responseText: String,
        context: SourceFileAnalysisContext
    ) -> CodeAnalysisResponseParsingResult {
        core.parse(
            responseText,
            context: context,
            schemaErrorMessage: "The baseline LLM response does not match the required schema.",
            decodeFindings: {
                try JSONDecoder().decode(
                    BaselineCodeAnalysisResponse.self,
                    from: $0
                ).findings
            },
            resolve: { finding, _ in
                    .accepted(
                        ResolvedCodeAnalysisFinding(
                            ruleID: nil,
                            title: finding.title,
                            explanation: finding.explanation,
                            evidence: finding.evidence
                        ))
            }
        )
    }
}

private struct BaselineCodeAnalysisResponse: Decodable {
    let findings: [BaselineCodeAnalysisFindingResponse]
    
    private enum CodingKeys: String, CodingKey, CaseIterable { case findings }
    
    init(from decoder: any Decoder) throws {
        try rejectUnknownResponseKeys(
            Set(CodingKeys.allCases.map(\.rawValue)),
            from: decoder
        )
        findings = try decoder.container(keyedBy: CodingKeys.self).decode(
            [BaselineCodeAnalysisFindingResponse].self,
            forKey: .findings
        )
    }
}

private struct BaselineCodeAnalysisFindingResponse: Decodable {
    let title: String
    let explanation: String
    let evidence: [CodeAnalysisEvidenceResponse]
    
    private enum CodingKeys: String, CodingKey, CaseIterable {
        case title
        case explanation
        case evidence
    }
    
    init(from decoder: any Decoder) throws {
        try rejectUnknownResponseKeys(
            Set(CodingKeys.allCases.map(\.rawValue)),
            from: decoder
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        explanation = try container.decode(String.self, forKey: .explanation)
        evidence = try container.decode(
            [CodeAnalysisEvidenceResponse].self,
            forKey: .evidence
        )
    }
}
