import ArcaDomain
import Foundation

struct CodeAnalysisResponseParserCore: Sendable {
    let limits: CodeAnalysisResponseLimits
    
    func parse<RawFinding>(
        _ responseText: String,
        context: SourceFileAnalysisContext,
        schemaErrorMessage: String,
        decodeFindings: (Data) throws -> [RawFinding],
        resolve: (RawFinding, Int) -> CodeAnalysisFindingResolution
    ) -> CodeAnalysisResponseParsingResult {
        guard limits.isValid else {
            return rejected(
                code: "ARCA-LLM-ANALYSIS-INVALID-CONFIGURATION",
                message: "Code-analysis response limits must be greater than zero."
            )
        }
        guard responseText.utf8.count <= limits.maximumResponseUTF8Bytes else {
            return rejected(
                code: "ARCA-LLM-ANALYSIS-RESPONSE-TOO-LARGE",
                message: "The LLM code-analysis response exceeds the maximum size."
            )
        }
        guard let jsonText = LLMJSONDocumentExtractor.extract(from: responseText),
              let data = jsonText.data(using: .utf8)
        else {
            return invalidJSON()
        }
        do {
            _ = try JSONSerialization.jsonObject(with: data)
        } catch {
            return invalidJSON()
        }
        
        let findings: [RawFinding]
        do {
            findings = try decodeFindings(data)
        } catch {
            return rejected(
                code: "ARCA-LLM-ANALYSIS-INVALID-SCHEMA",
                message: schemaErrorMessage
            )
        }
        guard findings.count <= limits.maximumFindingCount else {
            return rejected(
                code: "ARCA-LLM-ANALYSIS-RESPONSE-TOO-LARGE",
                message: "The LLM code-analysis response contains too many findings."
            )
        }
        
        let sourceLines = SourceTextLineExtractor.lines(in: context.sourceContent)
        guard sourceLines.count == context.lineCount else {
            return rejected(
                code: "ARCA-LLM-ANALYSIS-INVALID-RANGE",
                message: "The supplied source line count does not match its content."
            )
        }
        let sourceValidator = CodeAnalysisSourceValidator(
            sourceLines: sourceLines,
            limits: limits
        )
        
        var candidates: [FindingCandidate] = []
        var diagnostics: [LLMIssueDetectionDiagnostic] = []
        for (findingIndex, rawFinding) in findings.enumerated() {
            let finding: ResolvedCodeAnalysisFinding
            switch resolve(rawFinding, findingIndex) {
            case .accepted(let resolved):
                finding = resolved
            case .rejected(let diagnostic):
                diagnostics.append(diagnostic)
                continue
            }
            
            let title = finding.title.trimmed
            let explanation = finding.explanation.trimmed
            guard !title.isEmpty,
                  title.utf8.count <= limits.maximumExplanationUTF8Bytes,
                  !explanation.isEmpty,
                  explanation.utf8.count <= limits.maximumExplanationUTF8Bytes
            else {
                diagnostics.append(
                    codeAnalysisDiagnostic(
                        code: "ARCA-LLM-ANALYSIS-INVALID-SCHEMA",
                        message: "Finding \(findingIndex + 1) has an empty or oversized title or explanation."
                    ))
                continue
            }
            guard !finding.evidence.isEmpty,
                  finding.evidence.count <= limits.maximumEvidenceCountPerFinding
            else {
                diagnostics.append(
                    codeAnalysisDiagnostic(
                        code: "ARCA-LLM-ANALYSIS-INVALID-EVIDENCE",
                        message: "Finding \(findingIndex + 1) has an invalid number of evidence items."
                    ))
                continue
            }
            
            switch validatedEvidence(
                finding.evidence,
                sourceValidator: sourceValidator
            ) {
            case .accepted(let evidence):
                let startLine = evidence.map(\.range.startLine).min()!
                let endLine = evidence.map(\.range.endLine).max()!
                do {
                    candidates.append(
                        try FindingCandidate(
                            ruleID: finding.ruleID,
                            title: title,
                            explanation: explanation,
                            filePath: context.filePath,
                            range: sourceValidator.sourceRange(
                                startLine: startLine,
                                endLine: endLine
                            ),
                            evidence: evidence
                        ))
                } catch {
                    diagnostics.append(
                        codeAnalysisDiagnostic(
                            code: "ARCA-LLM-ANALYSIS-INVALID-SCHEMA",
                            message: "Finding \(findingIndex + 1) could not be represented as a candidate."
                        ))
                }
            case .rejected(let failure, let evidenceIndex):
                diagnostics.append(
                    codeAnalysisDiagnostic(
                        code: failure.code,
                        message: failure.message(
                            findingIndex: findingIndex,
                            evidenceIndex: evidenceIndex
                        )
                    ))
            }
        }
        
        return CodeAnalysisResponseParsingResult(
            candidates: candidates,
            diagnostics: diagnostics
        )
    }
    
    func rejected(
        code: String,
        message: String
    ) -> CodeAnalysisResponseParsingResult {
        CodeAnalysisResponseParsingResult(
            candidates: [],
            diagnostics: [codeAnalysisDiagnostic(code: code, message: message)]
        )
    }
    
    private func validatedEvidence(
        _ response: [CodeAnalysisEvidenceResponse],
        sourceValidator: CodeAnalysisSourceValidator
    ) -> CodeAnalysisEvidenceCollectionValidationResult {
        var evidence: [SourceCodeEvidence] = []
        for (index, item) in response.enumerated() {
            switch sourceValidator.validateEvidence(
                description: item.description,
                startLine: item.startLine,
                endLine: item.endLine
            ) {
            case .accepted(let item):
                evidence.append(item)
            case .rejected(let failure):
                return .rejected(failure, evidenceIndex: index)
            }
        }
        return .accepted(evidence)
    }
    
    private func invalidJSON() -> CodeAnalysisResponseParsingResult {
        rejected(
            code: "ARCA-LLM-ANALYSIS-INVALID-JSON",
            message: "The LLM code-analysis response is not a supported JSON document."
        )
    }
}

struct ResolvedCodeAnalysisFinding {
    let ruleID: String?
    let title: String
    let explanation: String
    let evidence: [CodeAnalysisEvidenceResponse]
}

enum CodeAnalysisFindingResolution {
    case accepted(ResolvedCodeAnalysisFinding)
    case rejected(LLMIssueDetectionDiagnostic)
}

private enum CodeAnalysisEvidenceCollectionValidationResult {
    case accepted([SourceCodeEvidence])
    case rejected(CodeAnalysisEvidenceValidationFailure, evidenceIndex: Int)
}

struct CodeAnalysisEvidenceResponse: Decodable {
    let description: String
    let startLine: Int
    let endLine: Int
    
    private enum CodingKeys: String, CodingKey, CaseIterable {
        case description
        case startLine
        case endLine
    }
    
    init(from decoder: any Decoder) throws {
        try rejectUnknownResponseKeys(
            Set(CodingKeys.allCases.map(\.rawValue)),
            from: decoder
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        description = try container.decode(String.self, forKey: .description)
        startLine = try container.decode(Int.self, forKey: .startLine)
        endLine = try container.decode(Int.self, forKey: .endLine)
    }
}

func codeAnalysisDiagnostic(
    code: String,
    message: String
) -> LLMIssueDetectionDiagnostic {
    LLMIssueDetectionDiagnostic(code: code, message: message)
}

private struct AnyResponseCodingKey: CodingKey {
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

func rejectUnknownResponseKeys(
    _ allowedKeys: Set<String>,
    from decoder: any Decoder
) throws {
    let container = try decoder.container(keyedBy: AnyResponseCodingKey.self)
    let unknownKeys = container.allKeys.map(\.stringValue).filter {
        !allowedKeys.contains($0)
    }
    guard unknownKeys.isEmpty else {
        throw DecodingError.dataCorrupted(
            .init(
                codingPath: decoder.codingPath,
                debugDescription: "Unknown response keys: \(unknownKeys.sorted())."
            ))
    }
}

extension String {
    fileprivate var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
