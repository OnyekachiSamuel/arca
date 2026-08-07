import Foundation

public enum SwiftLintAnalyzerError: Equatable, LocalizedError, Sendable {
    case timedOut
    case invalidJSON
    case unsupportedSeverity(String)
    case executionFailed(status: Int32, message: String)

    public var errorDescription: String? {
        switch self {
        case .timedOut:
            "SwiftLint exceeded its configured timeout."
        case .invalidJSON:
            "SwiftLint returned invalid JSON output."
        case .unsupportedSeverity(let severity):
            "SwiftLint returned unsupported severity '\(severity)'."
        case .executionFailed(let status, let message):
            "SwiftLint failed with status \(status): \(message)"
        }
    }
}
