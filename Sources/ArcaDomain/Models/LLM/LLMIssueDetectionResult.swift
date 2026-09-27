public struct LLMIssueDetectionResult: Codable, Equatable, Sendable {
  public let candidates: [FindingCandidate]
  public let diagnostics: [LLMIssueDetectionDiagnostic]
  public let executionMetadata: LLMExecutionMetadata

  public init(
    candidates: [FindingCandidate],
    diagnostics: [LLMIssueDetectionDiagnostic] = [],
    executionMetadata: LLMExecutionMetadata
  ) {
    self.candidates = candidates
    self.diagnostics = diagnostics
    self.executionMetadata = executionMetadata
  }
}
