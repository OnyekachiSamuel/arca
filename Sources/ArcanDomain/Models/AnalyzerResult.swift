import Foundation

public struct AnalyzerResult: Codable, Equatable, Sendable {
    public let analyzerID: String
    public let findings: [Finding]
    public let tool: ToolMetadata?
    public let durationMilliseconds: Int

    public init(
        analyzerID: String,
        findings: [Finding],
        tool: ToolMetadata? = nil,
        durationMilliseconds: Int = 0
    ) {
        self.analyzerID = analyzerID
        self.findings = findings
        self.tool = tool
        self.durationMilliseconds = durationMilliseconds
    }

    private enum CodingKeys: String, CodingKey {
        case analyzerID
        case findings
        case tool
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
        durationMilliseconds = try container.decodeIfPresent(
            Int.self,
            forKey: .durationMilliseconds
        ) ?? 0
    }
}
