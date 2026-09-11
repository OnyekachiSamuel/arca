import Foundation

public struct AnalyzerResult: Codable, Equatable, Sendable {
  public let analyzerID: String
  public let candidates: [FindingCandidate]
  public let executionStatus: AnalyzerExecutionStatus
  public let diagnostics: [AnalyzerDiagnostic]
  public let llmExecutionMetadata: LLMExecutionMetadata?

  public init(
    analyzerID: String,
    candidates: [FindingCandidate],
    executionStatus: AnalyzerExecutionStatus = .completed,
    diagnostics: [AnalyzerDiagnostic] = [],
    llmExecutionMetadata: LLMExecutionMetadata? = nil
  ) {
    self.analyzerID = analyzerID
    self.candidates = candidates
    self.executionStatus = executionStatus
    self.diagnostics = diagnostics
    self.llmExecutionMetadata = llmExecutionMetadata
  }

}
