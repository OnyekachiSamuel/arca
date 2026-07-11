import Foundation

public struct ReviewReport: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let requestID: UUID
    public let findings: [Finding]
    public let analyzerResults: [AnalyzerResult]

    public init(
        schemaVersion: Int,
        requestID: UUID,
        findings: [Finding],
        analyzerResults: [AnalyzerResult]
    ) {
        self.schemaVersion = schemaVersion
        self.requestID = requestID
        self.findings = findings
        self.analyzerResults = analyzerResults
    }
}
