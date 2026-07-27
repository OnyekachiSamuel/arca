import Foundation

public struct AnalyzerResult: Codable, Equatable, Sendable {
    public let analyzerID: String
    public let findings: [Finding]
    public let candidates: [FindingCandidate]
    public let tool: ToolMetadata?
    public let executionStatus: AnalyzerExecutionStatus
    public let diagnostics: [AnalyzerDiagnostic]
    public let durationMilliseconds: Int
    public let llmExecutionMetadata: LLMAnalyzerExecutionMetadata?

    public init(
        analyzerID: String,
        findings: [Finding],
        candidates: [FindingCandidate] = [],
        tool: ToolMetadata? = nil,
        executionStatus: AnalyzerExecutionStatus = .completed,
        diagnostics: [AnalyzerDiagnostic] = [],
        durationMilliseconds: Int = 0,
        llmExecutionMetadata: LLMAnalyzerExecutionMetadata? = nil
    ) {
        self.analyzerID = analyzerID
        self.findings = findings
        self.candidates = candidates
        self.tool = tool
        self.executionStatus = executionStatus
        self.diagnostics = diagnostics
        self.durationMilliseconds = durationMilliseconds
        self.llmExecutionMetadata = llmExecutionMetadata
    }

    private enum CodingKeys: String, CodingKey {
        case analyzerID
        case findings
        case candidates
        case tool
        case executionStatus
        case diagnostics
        case durationMilliseconds
        case llmExecutionMetadata
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        analyzerID = try container.decode(String.self, forKey: .analyzerID)
        findings = try container.decode([Finding].self, forKey: .findings)
        candidates = try container.decodeIfPresent(
            [FindingCandidate].self,
            forKey: .candidates
        ) ?? []
        tool = try container.decodeIfPresent(
            ToolMetadata.self,
            forKey: .tool
        )
        executionStatus = try container.decodeIfPresent(
            AnalyzerExecutionStatus.self,
            forKey: .executionStatus
        ) ?? .completed
        diagnostics = try container.decodeIfPresent(
            [AnalyzerDiagnostic].self,
            forKey: .diagnostics
        ) ?? []
        durationMilliseconds = try container.decodeIfPresent(
            Int.self,
            forKey: .durationMilliseconds
        ) ?? 0
        llmExecutionMetadata = try container.decodeIfPresent(
            LLMAnalyzerExecutionMetadata.self,
            forKey: .llmExecutionMetadata
        )
    }
}
