public struct AnalyzerDiagnostic: Codable, Equatable, Sendable {
    public let code: String
    public let severity: Severity
    public let message: String

    public init(
        code: String,
        severity: Severity,
        message: String
    ) {
        self.code = code
        self.severity = severity
        self.message = message
    }
}
