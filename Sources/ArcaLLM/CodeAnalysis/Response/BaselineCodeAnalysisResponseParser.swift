import ArcaDomain
import Foundation

public struct BaselineCodeAnalysisResponseParser: Sendable {
  private let limits: CodeAnalysisResponseLimits

  public init(
    limits: CodeAnalysisResponseLimits = .default
  ) {
    self.limits = limits
  }

  public func parse(
    _ responseText: String,
    context: SourceFileAnalysisContext
  ) -> CodeAnalysisResponseParsingResult {
    guard limits.isValid else {
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
    for (findingIndex, finding) in response.findings.enumerated() {
      let title = finding.title.trimmed
      let explanation = finding.explanation.trimmed
      guard !title.isEmpty,
        title.utf8.count <= limits.maximumExplanationUTF8Bytes,
        !explanation.isEmpty,
        explanation.utf8.count <= limits.maximumExplanationUTF8Bytes
      else {
        diagnostics.append(
          diagnostic(
            code: "ARCA-LLM-ANALYSIS-INVALID-SCHEMA",
            message: "Finding \(findingIndex + 1) has an empty or oversized title or explanation."
          ))
        continue
      }
      guard !finding.evidence.isEmpty,
        finding.evidence.count <= limits.maximumEvidenceCountPerFinding
      else {
        diagnostics.append(
          diagnostic(
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
              ruleID: nil,
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
            diagnostic(
              code: "ARCA-LLM-ANALYSIS-INVALID-SCHEMA",
              message: "Finding \(findingIndex + 1) could not be represented as a candidate."
            ))
        }
      case .rejected(let failure, let evidenceIndex):
        diagnostics.append(
          diagnostic(
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

  private func validatedEvidence(
    _ response: [BaselineCodeAnalysisEvidenceResponse],
    sourceValidator: CodeAnalysisSourceValidator
  ) -> EvidenceCollectionValidationResult {
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
  ) -> LLMIssueDetectionDiagnostic {
    LLMIssueDetectionDiagnostic(code: code, message: message)
  }
}

private enum EvidenceCollectionValidationResult {
  case accepted([SourceCodeEvidence])
  case rejected(CodeAnalysisEvidenceValidationFailure, evidenceIndex: Int)
}

private struct BaselineCodeAnalysisResponse: Decodable {
  let findings: [BaselineCodeAnalysisFindingResponse]

  private enum CodingKeys: String, CodingKey, CaseIterable { case findings }

  init(from decoder: any Decoder) throws {
    try rejectUnknownBaselineKeys(
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
  let evidence: [BaselineCodeAnalysisEvidenceResponse]

  private enum CodingKeys: String, CodingKey, CaseIterable {
    case title
    case explanation
    case evidence
  }

  init(from decoder: any Decoder) throws {
    try rejectUnknownBaselineKeys(
      Set(CodingKeys.allCases.map(\.rawValue)),
      from: decoder
    )
    let container = try decoder.container(keyedBy: CodingKeys.self)
    title = try container.decode(String.self, forKey: .title)
    explanation = try container.decode(String.self, forKey: .explanation)
    evidence = try container.decode(
      [BaselineCodeAnalysisEvidenceResponse].self,
      forKey: .evidence
    )
  }
}

private struct BaselineCodeAnalysisEvidenceResponse: Decodable {
  let description: String
  let startLine: Int
  let endLine: Int

  private enum CodingKeys: String, CodingKey, CaseIterable {
    case description
    case startLine
    case endLine
  }

  init(from decoder: any Decoder) throws {
    try rejectUnknownBaselineKeys(
      Set(CodingKeys.allCases.map(\.rawValue)),
      from: decoder
    )
    let container = try decoder.container(keyedBy: CodingKeys.self)
    description = try container.decode(String.self, forKey: .description)
    startLine = try container.decode(Int.self, forKey: .startLine)
    endLine = try container.decode(Int.self, forKey: .endLine)
  }
}

private struct BaselineResponseCodingKey: CodingKey {
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

private func rejectUnknownBaselineKeys(
  _ allowedKeys: Set<String>,
  from decoder: any Decoder
) throws {
  let container = try decoder.container(keyedBy: BaselineResponseCodingKey.self)
  let unknown = container.allKeys.map(\.stringValue).filter {
    !allowedKeys.contains($0)
  }
  guard unknown.isEmpty else {
    throw DecodingError.dataCorrupted(
      .init(
        codingPath: decoder.codingPath,
        debugDescription: "Unknown response keys: \(unknown.sorted())."
      ))
  }
}

extension String {
  fileprivate var trimmed: String {
    trimmingCharacters(in: .whitespacesAndNewlines)
  }
}
