import ArcaDomain
import Foundation

public struct BaselineCodeAnalysisParsingResult: Equatable, Sendable {
    public let findings: [LLMCodeAnalysisFinding]
    public let diagnostics: [AnalyzerDiagnostic]

    public init(
        findings: [LLMCodeAnalysisFinding],
        diagnostics: [AnalyzerDiagnostic]
    ) {
        self.findings = findings
        self.diagnostics = diagnostics
    }
}

public struct BaselineCodeAnalysisResponseParser: Sendable {
    private let sourceIdentifiers: [String]
    private let limits: CodeAnalysisResponseLimits
    private let retainsEvidenceExcerptMismatches: Bool

    public init(
        sourceIdentifiers: [String],
        limits: CodeAnalysisResponseLimits = .default,
        retainsEvidenceExcerptMismatches: Bool = false
    ) {
        var encountered: Set<String> = []
        self.sourceIdentifiers = sourceIdentifiers.filter {
            encountered.insert($0).inserted
        }
        self.limits = limits
        self.retainsEvidenceExcerptMismatches =
            retainsEvidenceExcerptMismatches
    }

    public func parse(
        _ responseText: String,
        context: SourceFileAnalysisContext,
        metadata: [String: FindingMetadataValue] = [:]
    ) -> BaselineCodeAnalysisParsingResult {
        guard limits.isValid,
              !sourceIdentifiers.isEmpty,
              sourceIdentifiers.allSatisfy({ !$0.trimmed.isEmpty }) else {
            return rejected(
                code: "ARCA-LLM-ANALYSIS-INVALID-CONFIGURATION",
                message: "Baseline code-analysis response configuration is invalid."
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
            return invalidJSON()
        }
        do {
            _ = try JSONSerialization.jsonObject(with: data)
        } catch {
            return invalidJSON()
        }

        let response: BaselineCodeAnalysisResponse
        do {
            response = try JSONDecoder().decode(
                BaselineCodeAnalysisResponse.self,
                from: data
            )
        } catch {
            return rejected(
                code: "ARCA-LLM-ANALYSIS-INVALID-SCHEMA",
                message: "The baseline LLM response does not match the required schema."
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

        var findings: [LLMCodeAnalysisFinding] = []
        var diagnostics: [AnalyzerDiagnostic] = []
        for (findingIndex, responseFinding) in response.findings.enumerated() {
            let findingNumber = findingIndex + 1
            guard isSafePath(responseFinding.filePath),
                  responseFinding.filePath == context.filePath else {
                diagnostics.append(diagnostic(
                    code: "ARCA-LLM-ANALYSIS-INVALID-PATH",
                    message: "Finding \(findingNumber) references invalid file path '\(responseFinding.filePath)'."
                ))
                continue
            }
            guard isValid(
                startLine: responseFinding.startLine,
                endLine: responseFinding.endLine,
                lineCount: context.lineCount
            ) else {
                diagnostics.append(diagnostic(
                    code: "ARCA-LLM-ANALYSIS-INVALID-RANGE",
                    message: "Finding \(findingNumber) has a line range outside '\(context.filePath)'."
                ))
                continue
            }

            let title = responseFinding.title.trimmed
            let explanation = responseFinding.explanation.trimmed
            guard !title.isEmpty,
                  title.utf8.count <= limits.maximumExplanationUTF8Bytes,
                  !explanation.isEmpty,
                  explanation.utf8.count
                    <= limits.maximumExplanationUTF8Bytes else {
                diagnostics.append(diagnostic(
                    code: "ARCA-LLM-ANALYSIS-INVALID-SCHEMA",
                    message: "Finding \(findingNumber) has an empty or oversized title or explanation."
                ))
                continue
            }
            guard !responseFinding.evidence.isEmpty,
                  responseFinding.evidence.count
                    <= limits.maximumEvidenceCountPerFinding else {
                diagnostics.append(diagnostic(
                    code: "ARCA-LLM-ANALYSIS-INVALID-EVIDENCE",
                    message: "Finding \(findingNumber) has an invalid number of evidence items."
                ))
                continue
            }

            var evidence: [FindingEvidence] = []
            var findingDiagnostics: [AnalyzerDiagnostic] = []
            var invalidEvidenceMessage: String?
            for (evidenceIndex, item) in responseFinding.evidence.enumerated() {
                let description = item.description.trimmed
                guard !description.isEmpty,
                      description.utf8.count
                        <= limits.maximumEvidenceDescriptionUTF8Bytes,
                      !item.excerpt.trimmed.isEmpty,
                      item.excerpt.utf8.count
                        <= limits.maximumEvidenceExcerptUTF8Bytes,
                      isValid(
                        startLine: item.startLine,
                        endLine: item.endLine,
                        lineCount: sourceLines.count
                      ),
                      item.startLine >= responseFinding.startLine,
                      item.endLine <= responseFinding.endLine else {
                    invalidEvidenceMessage = "Finding \(findingNumber), evidence \(evidenceIndex + 1) is invalid."
                    break
                }

                let selectedSource = sourceLines[
                    (item.startLine - 1)...(item.endLine - 1)
                ]
                .map { PromptTextRedactor.redactCommonSecrets(in: $0) }
                .joined(separator: "\n")
                let excerptMatches = selectedSource.contains(item.excerpt)
                if !excerptMatches && !retainsEvidenceExcerptMismatches {
                    invalidEvidenceMessage = "Finding \(findingNumber), evidence \(evidenceIndex + 1) excerpt does not exactly match source lines \(item.startLine)–\(item.endLine)."
                    break
                }

                evidence.append(.sourceCode(SourceCodeEvidence(
                    description: description,
                    range: sourceRange(
                        startLine: item.startLine,
                        endLine: item.endLine,
                        sourceLines: sourceLines
                    ),
                    excerpt: item.excerpt
                )))
                if !excerptMatches {
                    findingDiagnostics.append(diagnostic(
                        code: "ARCA-LLM-ANALYSIS-EVIDENCE-EXCERPT-MISMATCH",
                        message: "Evidence \(evidenceIndex + 1) could not be matched exactly to source lines \(item.startLine)–\(item.endLine)."
                    ))
                }
            }
            if let invalidEvidenceMessage {
                diagnostics.append(diagnostic(
                    code: "ARCA-LLM-ANALYSIS-INVALID-EVIDENCE",
                    message: invalidEvidenceMessage
                ))
                continue
            }

            findings.append(LLMCodeAnalysisFinding(
                canonicalRuleID: nil,
                title: title,
                issueType: responseFinding.issueType,
                explanation: explanation,
                filePath: context.filePath,
                range: sourceRange(
                    startLine: responseFinding.startLine,
                    endLine: responseFinding.endLine,
                    sourceLines: sourceLines
                ),
                severity: responseFinding.severity,
                evidence: evidence,
                sourceIdentifiers: sourceIdentifiers,
                metadata: metadata
            ))
            diagnostics.append(contentsOf: findingDiagnostics)
        }

        return BaselineCodeAnalysisParsingResult(
            findings: findings,
            diagnostics: diagnostics
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
        startLine >= 1 && endLine >= startLine && endLine <= lineCount
    }

    private func isSafePath(_ path: String) -> Bool {
        guard !path.trimmed.isEmpty,
              path == path.trimmed,
              !path.hasPrefix("/"),
              path.lowercased().hasSuffix(".swift"),
              !path.contains("\0") else {
            return false
        }
        return path.split(separator: "/", omittingEmptySubsequences: false)
            .allSatisfy { !$0.isEmpty && $0 != "." && $0 != ".." }
    }

    private func invalidJSON() -> BaselineCodeAnalysisParsingResult {
        rejected(
            code: "ARCA-LLM-ANALYSIS-INVALID-JSON",
            message: "The LLM code-analysis response is not a supported JSON document."
        )
    }

    private func rejected(
        code: String,
        message: String
    ) -> BaselineCodeAnalysisParsingResult {
        BaselineCodeAnalysisParsingResult(
            findings: [],
            diagnostics: [diagnostic(code: code, message: message)]
        )
    }

    private func diagnostic(
        code: String,
        message: String
    ) -> AnalyzerDiagnostic {
        AnalyzerDiagnostic(code: code, severity: .warning, message: message)
    }
}

private struct BaselineCodeAnalysisResponse: Decodable {
    let findings: [BaselineCodeAnalysisFindingResponse]
}

private struct BaselineCodeAnalysisFindingResponse: Decodable {
    let title: String
    let issueType: LLMDetectedIssueType
    let filePath: String
    let explanation: String
    let severity: Severity
    let startLine: Int
    let endLine: Int
    let evidence: [BaselineCodeAnalysisEvidenceResponse]
}

private struct BaselineCodeAnalysisEvidenceResponse: Decodable {
    let description: String
    let startLine: Int
    let endLine: Int
    let excerpt: String
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
