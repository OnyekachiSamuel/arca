import Foundation

public struct AnalyzerResult: Codable, Equatable, Sendable {
    public let analyzerID: String
    public let findings: [Finding]

    public init(analyzerID: String, findings: [Finding]) {
        self.analyzerID = analyzerID
        self.findings = findings
    }
}
