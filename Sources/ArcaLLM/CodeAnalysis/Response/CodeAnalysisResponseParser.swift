import ArcaDomain
import ArcaKnowledge
import Foundation

public struct CodeAnalysisResponseParser: Sendable {
  private let knowledgeByRuleID: [String: RuleKnowledge]
  private let limits: CodeAnalysisResponseLimits

  public init(
    rules: [RuleKnowledge],
    limits: CodeAnalysisResponseLimits = .default
  ) {
    knowledgeByRuleID = Dictionary(
      rules.map { ($0.ruleID, $0) },
      uniquingKeysWith: { first, _ in first }
    )
    self.limits = limits
  }

  public func parse(
    _ responseText: String,
    context: SourceFileAnalysisContext
  ) -> CodeAnalysisResponseParsingResult {
    guard limits.isValid else {
      return rejected(
        code: "ARCA-LLM-ANALYSIS-INVALID-CONFIGURATION",
        message: "Code-analysis response limits must be greater than zero."
      )
    }
    guard !knowledgeByRuleID.isEmpty else {
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

    let response: CodeAnalysisResponse
    do {
      response = try JSONDecoder().decode(CodeAnalysisResponse.self, from: data)
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
      guard let knowledge = knowledgeByRuleID[finding.ruleID] else {
        diagnostics.append(
          diagnostic(
            code: "ARCA-LLM-ANALYSIS-UNKNOWN-RULE",
            message: "Finding \(findingIndex + 1) references unknown rule ID '\(finding.ruleID)'."
          ))
        continue
      }
      let explanation = finding.explanation.trimmed
      guard !explanation.isEmpty,
        explanation.utf8.count <= limits.maximumExplanationUTF8Bytes
      else {
        diagnostics.append(
          diagnostic(
            code: "ARCA-LLM-ANALYSIS-INVALID-SCHEMA",
            message: "Finding \(findingIndex + 1) has an empty or oversized explanation."
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
              ruleID: knowledge.ruleID,
              title: knowledge.title,
              explanation: explanation,
              filePath: context.filePath,
              range: sourceValidator.sourceRange(
                startLine: startLine,
                endLine: endLine
              ),
              issueType: knowledge.issueType,
              category: knowledge.category,
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
    _ response: [CodeAnalysisEvidenceResponse],
    sourceValidator: CodeAnalysisSourceValidator
  ) -> GuidedEvidenceCollectionValidationResult {
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

private enum GuidedEvidenceCollectionValidationResult {
  case accepted([SourceCodeEvidence])
  case rejected(CodeAnalysisEvidenceValidationFailure, evidenceIndex: Int)
}

private struct CodeAnalysisResponse: Decodable {
  let findings: [CodeAnalysisFindingResponse]

  private enum CodingKeys: String, CodingKey, CaseIterable { case findings }

  init(from decoder: any Decoder) throws {
    try rejectUnknownKeys(
      Set(CodingKeys.allCases.map(\.rawValue)),
      from: decoder
    )
    findings = try decoder.container(keyedBy: CodingKeys.self).decode(
      [CodeAnalysisFindingResponse].self,
      forKey: .findings
    )
  }
}

private struct CodeAnalysisFindingResponse: Decodable {
  let ruleID: String
  let explanation: String
  let evidence: [CodeAnalysisEvidenceResponse]

  private enum CodingKeys: String, CodingKey, CaseIterable {
    case ruleID
    case explanation
    case evidence
  }

  init(from decoder: any Decoder) throws {
    try rejectUnknownKeys(
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

private struct CodeAnalysisEvidenceResponse: Decodable {
  let description: String
  let startLine: Int
  let endLine: Int

  private enum CodingKeys: String, CodingKey, CaseIterable {
    case description
    case startLine
    case endLine
  }

  init(from decoder: any Decoder) throws {
    try rejectUnknownKeys(
      Set(CodingKeys.allCases.map(\.rawValue)),
      from: decoder
    )
    let container = try decoder.container(keyedBy: CodingKeys.self)
    description = try container.decode(String.self, forKey: .description)
    startLine = try container.decode(Int.self, forKey: .startLine)
    endLine = try container.decode(Int.self, forKey: .endLine)
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
