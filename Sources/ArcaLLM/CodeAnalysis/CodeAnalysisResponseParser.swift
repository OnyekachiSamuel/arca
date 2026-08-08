import ArcaDomain
import ArcaKnowledge
import Foundation

public struct CodeAnalysisResponseParser: Sendable {
    private let knowledgeProvider: any RuleKnowledgeProviding
    private let sourceIdentifiers: [String]
    private let limits: CodeAnalysisResponseLimits
    private let retainsEvidenceExcerptMismatches: Bool

    public init(
        knowledgeProvider: any RuleKnowledgeProviding,
        sourceIdentifier: String,
        limits: CodeAnalysisResponseLimits = .default,
        retainsEvidenceExcerptMismatches: Bool = false
    ) {
        self.knowledgeProvider = knowledgeProvider
        sourceIdentifiers = [sourceIdentifier]
        self.limits = limits
        self.retainsEvidenceExcerptMismatches =
            retainsEvidenceExcerptMismatches
    }

    public init(
        knowledgeProvider: any RuleKnowledgeProviding,
        sourceIdentifiers: [String],
        limits: CodeAnalysisResponseLimits = .default,
        retainsEvidenceExcerptMismatches: Bool = false
    ) {
        self.knowledgeProvider = knowledgeProvider
        self.sourceIdentifiers = Self.unique(sourceIdentifiers)
        self.limits = limits
        self.retainsEvidenceExcerptMismatches =
            retainsEvidenceExcerptMismatches
    }

    public func parse(
        _ responseText: String,
        context: SourceFileAnalysisContext,
        analyzerMetadata: [String: FindingMetadataValue] = [:]
    ) -> CodeAnalysisResponseParsingResult {
        guard limits.isValid else {
            return rejected(
                code: "ARCA-LLM-ANALYSIS-INVALID-CONFIGURATION",
                message: "Code-analysis response limits must be greater than zero."
            )
        }
        guard !sourceIdentifiers.isEmpty,
              sourceIdentifiers.allSatisfy({ !$0.trimmed.isEmpty }) else {
            return rejected(
                code: "ARCA-LLM-ANALYSIS-INVALID-CONFIGURATION",
                message: "The LLM code analyzer source identifier must not be empty."
            )
        }
        guard responseText.utf8.count <= limits.maximumResponseUTF8Bytes else {
            return rejected(
                code: "ARCA-LLM-ANALYSIS-RESPONSE-TOO-LARGE",
                message: "The LLM code-analysis response exceeds the maximum size."
            )
        }
        guard let jsonText = LLMJSONDocumentExtractor.extract(
            from: responseText
        ), let data = jsonText.data(using: .utf8) else {
            return rejectedInvalidJSON()
        }

        do {
            _ = try JSONSerialization.jsonObject(with: data)
        } catch {
            return rejectedInvalidJSON()
        }

        let response: CodeAnalysisResponse

        do {
            response = try JSONDecoder().decode(
                CodeAnalysisResponse.self,
                from: data
            )
        } catch {
            return rejected(
                code: "ARCA-LLM-ANALYSIS-INVALID-SCHEMA",
                message: "The LLM code-analysis response does not match the required schema."
            )
        }

        guard response.findings.count <= limits.maximumFindingCount else {
            return rejected(
                code: "ARCA-LLM-ANALYSIS-RESPONSE-TOO-LARGE",
                message: "The LLM code-analysis response contains too many findings."
            )
        }

        let sourceLines = SourceTextLineExtractor.lines(
            in: context.sourceContent
        )
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
        var diagnostics: [AnalyzerDiagnostic] = []

        for (index, finding) in response.findings.enumerated() {
            switch validatedCandidate(
                from: finding,
                findingIndex: index,
                context: context,
                sourceValidator: sourceValidator,
                analyzerMetadata: analyzerMetadata
            ) {
            case let .accepted(candidate, candidateDiagnostics):
                candidates.append(candidate)
                diagnostics.append(contentsOf: candidateDiagnostics)
            case .rejected(let diagnostic):
                diagnostics.append(diagnostic)
            }
        }

        return CodeAnalysisResponseParsingResult(
            candidates: candidates,
            diagnostics: diagnostics
        )
    }

    private func validatedCandidate(
        from response: CodeAnalysisFindingResponse,
        findingIndex: Int,
        context: SourceFileAnalysisContext,
        sourceValidator: CodeAnalysisSourceValidator,
        analyzerMetadata: [String: FindingMetadataValue]
    ) -> CandidateValidationResult {
        let findingNumber = findingIndex + 1
        guard let knowledge = knowledgeProvider.knowledge(
            for: response.ruleID
        ) else {
            return .rejected(diagnostic(
                code: "ARCA-LLM-ANALYSIS-UNKNOWN-RULE",
                message: "Finding \(findingNumber) references unknown rule ID '\(response.ruleID)'."
            ))
        }
        guard sourceValidator.isSafePath(response.filePath),
              response.filePath == context.filePath else {
            return .rejected(diagnostic(
                code: "ARCA-LLM-ANALYSIS-INVALID-PATH",
                message: "Finding \(findingNumber) references invalid file path '\(response.filePath)'."
            ))
        }
        guard sourceValidator.isValidRange(
            startLine: response.startLine,
            endLine: response.endLine
        ) else {
            return .rejected(diagnostic(
                code: "ARCA-LLM-ANALYSIS-INVALID-RANGE",
                message: "Finding \(findingNumber) has a line range outside '\(context.filePath)'."
            ))
        }

        let explanation = response.explanation.trimmed
        guard !explanation.isEmpty,
              explanation.utf8.count
                <= limits.maximumExplanationUTF8Bytes else {
            return .rejected(diagnostic(
                code: "ARCA-LLM-ANALYSIS-INVALID-SCHEMA",
                message: "Finding \(findingNumber) has an empty or oversized explanation."
            ))
        }
        guard !response.evidence.isEmpty,
              response.evidence.count
                <= limits.maximumEvidenceCountPerFinding else {
            return .rejected(diagnostic(
                code: "ARCA-LLM-ANALYSIS-INVALID-EVIDENCE",
                message: "Finding \(findingNumber) has an invalid number of evidence items."
            ))
        }

        var evidence: [FindingEvidence] = []
        var evidenceDiagnostics: [AnalyzerDiagnostic] = []

        for (evidenceIndex, item) in response.evidence.enumerated() {
            switch validateEvidence(
                item,
                finding: response,
                sourceValidator: sourceValidator
            ) {
            case .accepted(let validatedEvidence):
                evidence.append(.sourceCode(validatedEvidence))
            case .rejected(let failure):
                if retainsEvidenceExcerptMismatches,
                   failure.isExcerptMismatch {
                    evidence.append(.sourceCode(SourceCodeEvidence(
                        description: item.description.trimmed,
                        range: sourceValidator.sourceRange(
                            startLine: item.startLine,
                            endLine: item.endLine
                        ),
                        excerpt: item.excerpt
                    )))
                    evidenceDiagnostics.append(diagnostic(
                        code: failure.code,
                        message: failure.evidenceVerificationMessage(
                            evidenceIndex: evidenceIndex
                        )
                    ))
                    continue
                }
                return .rejected(diagnostic(
                    code: failure.code,
                    message: failure.message(
                        findingIndex: findingIndex,
                        evidenceIndex: evidenceIndex
                    )
                ))
            }
        }

        do {
            return .accepted(try FindingCandidate(
                candidateID: UUID(),
                ruleID: knowledge.ruleID,
                title: knowledge.title,
                explanation: explanation,
                filePath: context.filePath,
                range: sourceValidator.sourceRange(
                    startLine: response.startLine,
                    endLine: response.endLine
                ),
                proposedSeverity: response.severity,
                proposedCategory: knowledge.category,
                evidence: evidence,
                sourceIdentifiers: sourceIdentifiers,
                analyzerMetadata: analyzerMetadata
            ), diagnostics: evidenceDiagnostics)
        } catch {
            return .rejected(diagnostic(
                code: "ARCA-LLM-ANALYSIS-INVALID-SCHEMA",
                message: "Finding \(findingNumber) could not be converted into a candidate finding."
            ))
        }
    }

    private static func unique(_ values: [String]) -> [String] {
        var encountered: Set<String> = []
        return values.filter { encountered.insert($0).inserted }
    }

    private func validateEvidence(
        _ response: CodeAnalysisEvidenceResponse,
        finding: CodeAnalysisFindingResponse,
        sourceValidator: CodeAnalysisSourceValidator
    ) -> CodeAnalysisEvidenceValidationResult {
        sourceValidator.validateEvidence(
            description: response.description,
            excerpt: response.excerpt,
            startLine: response.startLine,
            endLine: response.endLine,
            findingStartLine: finding.startLine,
            findingEndLine: finding.endLine
        )
    }

    private func rejectedInvalidJSON() -> CodeAnalysisResponseParsingResult {
        rejected(
            code: "ARCA-LLM-ANALYSIS-INVALID-JSON",
            message: "The LLM code-analysis response is not a supported JSON document."
        )
    }

    private func rejected(
        code: String,
        message: String
    ) -> CodeAnalysisResponseParsingResult {
        CodeAnalysisResponseParsingResult(
            candidates: [],
            diagnostics: [diagnostic(code: code, message: message)]
        )
    }

    private func diagnostic(
        code: String,
        message: String
    ) -> AnalyzerDiagnostic {
        AnalyzerDiagnostic(
            code: code,
            severity: .warning,
            message: message
        )
    }
}

private enum CandidateValidationResult {
    case accepted(
        FindingCandidate,
        diagnostics: [AnalyzerDiagnostic] = []
    )
    case rejected(AnalyzerDiagnostic)
}

private struct CodeAnalysisResponse: Decodable {
    let findings: [CodeAnalysisFindingResponse]

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case findings
    }

    init(from decoder: any Decoder) throws {
        try rejectUnknownKeys(
            Set(CodingKeys.allCases.map(\.rawValue)),
            from: decoder
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        findings = try container.decode(
            [CodeAnalysisFindingResponse].self,
            forKey: .findings
        )
    }
}

private struct CodeAnalysisFindingResponse: Decodable {
    let ruleID: String
    let filePath: String
    let explanation: String
    let severity: Severity
    let startLine: Int
    let endLine: Int
    let evidence: [CodeAnalysisEvidenceResponse]

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case ruleID
        case filePath
        case explanation
        case severity
        case startLine
        case endLine
        case evidence
    }

    init(from decoder: any Decoder) throws {
        try rejectUnknownKeys(
            Set(CodingKeys.allCases.map(\.rawValue)),
            from: decoder
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        ruleID = try container.decode(String.self, forKey: .ruleID)
        filePath = try container.decode(String.self, forKey: .filePath)
        explanation = try container.decode(
            String.self,
            forKey: .explanation
        )
        severity = try container.decode(Severity.self, forKey: .severity)
        startLine = try container.decode(Int.self, forKey: .startLine)
        endLine = try container.decode(Int.self, forKey: .endLine)
        evidence = try container.decode(
            [CodeAnalysisEvidenceResponse].self,
            forKey: .evidence
        )
    }
}

private struct CodeAnalysisEvidenceResponse: Decodable {
    let description: String
    let startLine: Int
    let endLine: Int
    let excerpt: String

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case description
        case startLine
        case endLine
        case excerpt
    }

    init(from decoder: any Decoder) throws {
        try rejectUnknownKeys(
            Set(CodingKeys.allCases.map(\.rawValue)),
            from: decoder
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        description = try container.decode(
            String.self,
            forKey: .description
        )
        startLine = try container.decode(Int.self, forKey: .startLine)
        endLine = try container.decode(Int.self, forKey: .endLine)
        excerpt = try container.decode(String.self, forKey: .excerpt)
    }
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

private func rejectUnknownKeys(
    _ allowedKeys: Set<String>,
    from decoder: any Decoder
) throws {
    let container = try decoder.container(
        keyedBy: AnyResponseCodingKey.self
    )
    let unknownKeys = container.allKeys
        .map(\.stringValue)
        .filter { !allowedKeys.contains($0) }

    guard unknownKeys.isEmpty else {
        throw DecodingError.dataCorrupted(
            DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Unknown response keys: \(unknownKeys.sorted().joined(separator: ", "))."
            )
        )
    }
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
