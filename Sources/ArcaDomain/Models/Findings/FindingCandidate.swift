import Foundation

public struct FindingCandidate: Codable, Equatable, Sendable {
  public let ruleID: String?
  public let title: String
  public let explanation: String
  public let filePath: String
  public let range: SourceRange?
  public let evidence: [SourceCodeEvidence]

  public init(
    ruleID: String?,
    title: String,
    explanation: String,
    filePath: String,
    range: SourceRange?,
    evidence: [SourceCodeEvidence]
  ) throws {
    guard ruleID.map({ !$0.isBlank }) ?? true else {
      throw FindingCandidateValidationError.missingRuleID
    }
    guard !title.isBlank else {
      throw FindingCandidateValidationError.missingTitle
    }
    guard !explanation.isBlank else {
      throw FindingCandidateValidationError.missingExplanation
    }
    guard !filePath.isBlank else {
      throw FindingCandidateValidationError.missingFilePath
    }
    guard range.map(Self.isValid) ?? true else {
      throw FindingCandidateValidationError.invalidSourceRange
    }
    guard !evidence.isEmpty else {
      throw FindingCandidateValidationError.missingEvidence
    }
    guard evidence.allSatisfy({ Self.isValid($0.range) }) else {
      throw FindingCandidateValidationError.invalidEvidenceSourceRange
    }
    self.ruleID = ruleID
    self.title = title
    self.explanation = explanation
    self.filePath = filePath
    self.range = range
    self.evidence = evidence
  }

  private enum CodingKeys: String, CodingKey {
    case ruleID
    case title
    case explanation
    case filePath
    case range
    case evidence
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    try self.init(
      ruleID: container.decodeIfPresent(String.self, forKey: .ruleID),
      title: container.decode(String.self, forKey: .title),
      explanation: container.decode(
        String.self,
        forKey: .explanation
      ),
      filePath: container.decode(String.self, forKey: .filePath),
      range: container.decodeIfPresent(
        SourceRange.self,
        forKey: .range
      ),
      evidence: container.decode(
        [SourceCodeEvidence].self,
        forKey: .evidence
      )
    )
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)

    try container.encodeIfPresent(ruleID, forKey: .ruleID)
    try container.encode(title, forKey: .title)
    try container.encode(explanation, forKey: .explanation)
    try container.encode(filePath, forKey: .filePath)
    try container.encodeIfPresent(range, forKey: .range)
    try container.encode(evidence, forKey: .evidence)
  }

  private static func isValid(_ range: SourceRange) -> Bool {
    let positionsAreOneBased =
      range.startLine > 0
      && range.startColumn > 0
      && range.endLine > 0
      && range.endColumn > 0
    let endFollowsStart =
      range.endLine > range.startLine
      || (range.endLine == range.startLine
        && range.endColumn >= range.startColumn)

    return positionsAreOneBased && endFollowsStart
  }
}

extension String {
  fileprivate var isBlank: Bool {
    trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }
}
