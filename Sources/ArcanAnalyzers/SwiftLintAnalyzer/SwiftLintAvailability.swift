import Foundation

public enum SwiftLintAvailability: Equatable, Sendable {
    case available(URL)
    case unavailable(SwiftLintUnavailableReason)
}

public enum SwiftLintUnavailableReason: Equatable, Sendable {
    case executableNotFound
    case configuredExecutableNotFound(String)
    case configuredExecutableNotRunnable(String)
    case executableCouldNotStart(path: String, reason: String)

    public var description: String {
        switch self {
        case .executableNotFound:
            "SwiftLint executable was not found."
        case .configuredExecutableNotFound(let path):
            "Configured SwiftLint executable does not exist: \(path)."
        case .configuredExecutableNotRunnable(let path):
            "Configured SwiftLint file is not executable: \(path)."
        case .executableCouldNotStart(let path, let reason):
            "SwiftLint executable could not start at \(path): \(reason)."
        }
    }
}
