import ArcanDomain
import ArcanKnowledge
import Foundation

public struct CodeAnalysisResponseParser: Sendable {
    private let knowledgeProvider: any RuleKnowledgeProviding
    private let sourceIdentifier: String
    private let limits: CodeAnalysisResponseLimits

    public init(
        knowledgeProvider: any RuleKnowledgeProviding,
        sourceIdentifier: String,
        limits: CodeAnalysisResponseLimits = .default
    ) {
        self.knowledgeProvider = knowledgeProvider
        self.sourceIdentifier = sourceIdentifier
        self.limits = limits
    }

    public func parse(
        _ responseText: String,
        context: SourceFileAnalysisContext,
        analyzerMetadata: [String: FindingMetadataValue] = [:]
    ) -> CodeAnalysisResponseParsingResult {
        guard limits.isValid else {
            return rejected(
                code: "ARCAN-LLM-ANALYSIS-INVALID-CONFIGURATION",
                message: "Code-analysis response limits must be greater than zero."
            )
        }
        guard !sourceIdentifier.trimmed.isEmpty else {
            return rejected(
                code: "ARCAN-LLM-ANALYSIS-INVALID-CONFIGURATION",
                message: "The LLM code analyzer source identifier must not be empty."
            )
        }
        guard responseText.utf8.count <= limits.maximumResponseUTF8Bytes else {
            return rejected(
                code: "ARCAN-LLM-ANALYSIS-RESPONSE-TOO-LARGE",
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
                code: "ARCAN-LLM-ANALYSIS-INVALID-SCHEMA",
                message: "The LLM code-analysis response does not match the required schema."
            )
        }

        guard response.findings.count <= limits.maximumFindingCount else {
            return rejected(
                code: "ARCAN-LLM-ANALYSIS-RESPONSE-TOO-LARGE",
                message: "The LLM code-analysis response contains too many findings."
            )
        }

        let sourceLines = SourceTextLineExtractor.lines(
            in: context.sourceContent
        )
        guard sourceLines.count == context.lineCount else {
            return rejected(
                code: "ARCAN-LLM-ANALYSIS-INVALID-RANGE",
                message: "The supplied source line count does not match its content."
            )
        }

        var candidates: [FindingCandidate] = []
        var diagnostics: [AnalyzerDiagnostic] = []

        for (index, finding) in response.findings.enumerated() {
            switch validatedCandidate(
                from: finding,
                findingIndex: index,
                context: context,
                sourceLines: sourceLines,
                analyzerMetadata: analyzerMetadata
            ) {
            case .accepted(let candidate):
                candidates.append(candidate)
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
        sourceLines: [String],
        analyzerMetadata: [String: FindingMetadataValue]
    ) -> CandidateValidationResult {
        guard let knowledge = knowledgeProvider.knowledge(
            for: response.ruleID
        ) else {
            return .rejected(diagnostic(
                code: "ARCAN-LLM-ANALYSIS-UNKNOWN-RULE",
                message: "Finding \(findingIndex) references unknown rule ID '\(response.ruleID)'."
            ))
        }
        guard isSafePath(response.filePath),
              response.filePath == context.filePath else {
            return .rejected(diagnostic(
                code: "ARCAN-LLM-ANALYSIS-INVALID-PATH",
                message: "Finding \(findingIndex) references invalid file path '\(response.filePath)'."
            ))
        }
        guard isValid(
            startLine: response.startLine,
            endLine: response.endLine,
            lineCount: context.lineCount
        ) else {
            return .rejected(diagnostic(
                code: "ARCAN-LLM-ANALYSIS-INVALID-RANGE",
                message: "Finding \(findingIndex) has a line range outside '\(context.filePath)'."
            ))
        }

        let explanation = response.explanation.trimmed
        guard !explanation.isEmpty,
              explanation.utf8.count
                <= limits.maximumExplanationUTF8Bytes else {
            return .rejected(diagnostic(
                code: "ARCAN-LLM-ANALYSIS-INVALID-SCHEMA",
                message: "Finding \(findingIndex) has an empty or oversized explanation."
            ))
        }
        guard !response.evidence.isEmpty,
              response.evidence.count
                <= limits.maximumEvidenceCountPerFinding else {
            return .rejected(diagnostic(
                code: "ARCAN-LLM-ANALYSIS-INVALID-EVIDENCE",
                message: "Finding \(findingIndex) has an invalid number of evidence items."
            ))
        }

        var evidence: [FindingEvidence] = []

        for item in response.evidence {
            guard let validatedEvidence = validatedEvidence(
                item,
                finding: response,
                sourceLines: sourceLines
            ) else {
                return .rejected(diagnostic(
                    code: "ARCAN-LLM-ANALYSIS-INVALID-EVIDENCE",
                    message: "Finding \(findingIndex) contains invalid or unsupported source evidence."
                ))
            }
            evidence.append(.sourceCode(validatedEvidence))
        }

        do {
            return .accepted(try FindingCandidate(
                candidateID: UUID(),
                ruleID: knowledge.ruleID,
                title: knowledge.title,
                explanation: explanation,
                filePath: context.filePath,
                range: sourceRange(
                    startLine: response.startLine,
                    endLine: response.endLine,
                    sourceLines: sourceLines
                ),
                proposedSeverity: response.severity,
                proposedCategory: knowledge.category,
                evidence: evidence,
                sourceIdentifiers: [sourceIdentifier],
                analyzerMetadata: analyzerMetadata
            ))
        } catch {
            return .rejected(diagnostic(
                code: "ARCAN-LLM-ANALYSIS-INVALID-SCHEMA",
                message: "Finding \(findingIndex) could not be converted into a candidate finding."
            ))
        }
    }

    private func validatedEvidence(
        _ response: CodeAnalysisEvidenceResponse,
        finding: CodeAnalysisFindingResponse,
        sourceLines: [String]
    ) -> SourceCodeEvidence? {
        let description = response.description.trimmed
        guard !description.isEmpty,
              description.utf8.count
                <= limits.maximumEvidenceDescriptionUTF8Bytes,
              !response.excerpt.trimmed.isEmpty,
              response.excerpt.utf8.count
                <= limits.maximumEvidenceExcerptUTF8Bytes,
              isValid(
                startLine: response.startLine,
                endLine: response.endLine,
                lineCount: sourceLines.count
              ),
              response.startLine >= finding.startLine,
              response.endLine <= finding.endLine else {
            return nil
        }

        let selectedSource = sourceLines[
            (response.startLine - 1)...(response.endLine - 1)
        ]
        .map { PromptTextRedactor.redactCommonSecrets(in: $0) }
        .joined(separator: "\n")

        guard selectedSource.contains(response.excerpt) else {
            return nil
        }

        return SourceCodeEvidence(
            description: description,
            range: sourceRange(
                startLine: response.startLine,
                endLine: response.endLine,
                sourceLines: sourceLines
            ),
            excerpt: response.excerpt
        )
    }

    private func sourceRange(
        startLine: Int,
        endLine: Int,
        sourceLines: [String]
    ) -> SourceRange {
        SourceRange(
            startLine: startLine,
            startColumn: 1,
            endLine: endLine,
            endColumn: sourceLines[endLine - 1].utf8.count + 1
        )
    }

    private func isValid(
        startLine: Int,
        endLine: Int,
        lineCount: Int
    ) -> Bool {
        startLine >= 1
            && endLine >= startLine
            && endLine <= lineCount
    }

    private func isSafePath(_ path: String) -> Bool {
        guard !path.trimmed.isEmpty,
              path == path.trimmed,
              !path.hasPrefix("/"),
              path.lowercased().hasSuffix(".swift"),
              !path.contains("\0") else {
            return false
        }

        let components = path.split(
            separator: "/",
            omittingEmptySubsequences: false
        )
        return components.allSatisfy {
            !$0.isEmpty && $0 != "." && $0 != ".."
        }
    }

    private func rejectedInvalidJSON() -> CodeAnalysisResponseParsingResult {
        rejected(
            code: "ARCAN-LLM-ANALYSIS-INVALID-JSON",
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
    case accepted(FindingCandidate)
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
