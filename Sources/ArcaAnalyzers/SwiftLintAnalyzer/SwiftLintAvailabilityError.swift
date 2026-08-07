import Foundation

public enum SwiftLintAvailabilityError: Equatable, LocalizedError, Sendable {
    case requiredToolUnavailable(SwiftLintUnavailableReason)

    public var errorDescription: String? {
        switch self {
        case .requiredToolUnavailable(let reason):
            "SwiftLint is required but unavailable: \(reason.description) "
                + "Install SwiftLint or set ARCA_SWIFTLINT_EXECUTABLE."
        }
    }
}
