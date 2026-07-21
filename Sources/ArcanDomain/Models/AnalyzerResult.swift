import Foundation

public struct AnalyzerResult: Codable, Equatable, Sendable {
    public let analyzerID: String
    public let findings: [Finding]
    public let tool: ToolMetadata?
    public let executionStatus: AnalyzerExecutionStatus
    public let diagnostics: [AnalyzerDiagnostic]
    public let durationMilliseconds: Int

    public init(
        analyzerID: String,
        findings: [Finding],
        tool: ToolMetadata? = nil,
        executionStatus: AnalyzerExecutionStatus = .completed,
        diagnostics: [AnalyzerDiagnostic] = [],
        durationMilliseconds: Int = 0
    ) {
        self.analyzerID = analyzerID
        self.findings = findings
        self.tool = tool
        self.executionStatus = executionStatus
        self.diagnostics = diagnostics
        self.durationMilliseconds = durationMilliseconds
    }

    private enum CodingKeys: String, CodingKey {
        case analyzerID
        case findings
        case tool
        case executionStatus
        case diagnostics
        case durationMilliseconds
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        analyzerID = try container.decode(String.self, forKey: .analyzerID)
        findings = try container.decode([Finding].self, forKey: .findings)
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
    }
}
