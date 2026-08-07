import Foundation

public enum GitDiffProviderError: Equatable, LocalizedError {
    case commandCouldNotRun(repositoryRoot: String, reason: String)
    case commandFailed(repositoryRoot: String)
    case invalidOutput(repositoryRoot: String)

    public var errorDescription: String? {
        switch self {
        case .commandCouldNotRun(let repositoryRoot, let reason):
            "Could not extract Git changes in \(repositoryRoot): \(reason)"
        case .commandFailed(let repositoryRoot):
            "Git could not produce diff data for: \(repositoryRoot)"
        case .invalidOutput(let repositoryRoot):
            "Git returned invalid diff data for: \(repositoryRoot)"
        }
    }
}
