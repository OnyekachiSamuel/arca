import Foundation

public enum Severity: String, Codable, CaseIterable, Sendable {
    case info
    case warning
    case error
    case critical
}
