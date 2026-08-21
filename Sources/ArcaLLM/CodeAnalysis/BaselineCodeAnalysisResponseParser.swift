import ArcaDomain
import Foundation

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
    ) -> CodeAnalysisResponseParsingResult {
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
        let sourceValidator = CodeAnalysisSourceValidator(
            sourceLines: sourceLines,
            limits: limits
        )

        var candidates: [FindingCandidate] = []
        var diagnostics: [AnalyzerDiagnostic] = []
        for (findingIndex, responseFinding) in response.findings.enumerated() {
            let findingNumber = findingIndex + 1
            guard sourceValidator.isSafePath(responseFinding.filePath),
                  responseFinding.filePath == context.filePath else {
                diagnostics.append(diagnostic(
                    code: "ARCA-LLM-ANALYSIS-INVALID-PATH",
                    message: "Finding \(findingNumber) references invalid file path '\(responseFinding.filePath)'."
                ))
                continue
            }
            guard sourceValidator.isValidRange(
                startLine: responseFinding.startLine,
                endLine: responseFinding.endLine
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
            var invalidEvidence: (
                failure: CodeAnalysisEvidenceValidationFailure,
                index: Int
            )?
            for (evidenceIndex, item) in responseFinding.evidence.enumerated() {
                switch sourceValidator.validateEvidence(
                    description: item.description,
                    excerpt: item.excerpt,
                    startLine: item.startLine,
                    endLine: item.endLine,
                    findingStartLine: responseFinding.startLine,
                    findingEndLine: responseFinding.endLine
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
                        findingDiagnostics.append(diagnostic(
                            code: failure.code,
                            message: failure.evidenceVerificationMessage(
                                evidenceIndex: evidenceIndex
                            )
                        ))
                    } else {
                        invalidEvidence = (failure, evidenceIndex)
                    }
                }
                if invalidEvidence != nil { break }
            }
            if let invalidEvidence {
                diagnostics.append(diagnostic(
                    code: invalidEvidence.failure.code,
                    message: invalidEvidence.failure.message(
                        findingIndex: findingIndex,
                        evidenceIndex: invalidEvidence.index
                    )
                ))
                continue
            }

            do {
                var candidateMetadata = metadata
                candidateMetadata["issueType"] = .string(
                    responseFinding.issueType.rawValue
                )
                candidates.append(try FindingCandidate(
                    candidateID: UUID(),
                    ruleID: nil,
                    title: title,
                    explanation: explanation,
                    filePath: context.filePath,
                    range: sourceValidator.sourceRange(
                        startLine: responseFinding.startLine,
                        endLine: responseFinding.endLine
                    ),
                    proposedSeverity: responseFinding.severity,
                    proposedCategory: category(
                        for: responseFinding.issueType
                    ),
                    evidence: evidence,
                    sourceIdentifiers: sourceIdentifiers,
                    analyzerMetadata: candidateMetadata
                ))
            } catch {
                diagnostics.append(diagnostic(
                    code: "ARCA-LLM-ANALYSIS-INVALID-SCHEMA",
                    message: "Finding \(findingNumber) could not be represented as a candidate."
                ))
                continue
            }
            diagnostics.append(contentsOf: findingDiagnostics)
        }

        return CodeAnalysisResponseParsingResult(
            candidates: candidates,
            diagnostics: diagnostics
        )
    }

    private func invalidJSON() -> CodeAnalysisResponseParsingResult {
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

    private func category(
        for issueType: BaselineIssueDetectedType
    ) -> FindingCategory {
        switch issueType {
        case .antiPattern:
            .antiPattern
        case .architecture:
            .architecture
        case .style:
            .style
        case .teamConvention:
            .teamConvention
        case .codeSmell, .general:
            .general
        }
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
    let issueType: BaselineIssueDetectedType
    let filePath: String
    let explanation: String
    let severity: Severity
    let startLine: Int
    let endLine: Int
    let evidence: [BaselineCodeAnalysisEvidenceResponse]
}

private enum BaselineIssueDetectedType: String, Decodable {
    case codeSmell
    case antiPattern
    case architecture
    case style
    case teamConvention
    case general
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
