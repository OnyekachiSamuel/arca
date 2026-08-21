import Foundation

public struct AnalyzerResult: Codable, Equatable, Sendable {
    public let analyzerID: String
    public let candidates: [FindingCandidate]
    public let tool: ToolMetadata?
    public let executionStatus: AnalyzerExecutionStatus
    public let diagnostics: [AnalyzerDiagnostic]
    public let durationMilliseconds: Int
    public let llmExecutionMetadata: LLMExecutionMetadata?

    public init(
        analyzerID: String,
        candidates: [FindingCandidate],
        tool: ToolMetadata? = nil,
        executionStatus: AnalyzerExecutionStatus = .completed,
        diagnostics: [AnalyzerDiagnostic] = [],
        durationMilliseconds: Int = 0,
        llmExecutionMetadata: LLMExecutionMetadata? = nil
    ) {
        self.analyzerID = analyzerID
        self.candidates = candidates
        self.tool = tool
        self.executionStatus = executionStatus
        self.diagnostics = diagnostics
        self.durationMilliseconds = durationMilliseconds
        self.llmExecutionMetadata = llmExecutionMetadata
    }

}
