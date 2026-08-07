import Foundation

public enum GitChangedSwiftFileFinderError: Equatable, LocalizedError {
    case commandCouldNotRun(repositoryRoot: String, reason: String)
    case commandFailed(repositoryRoot: String)
    case invalidStatusOutput(repositoryRoot: String)

    public var errorDescription: String? {
        switch self {
        case .commandCouldNotRun(let repositoryRoot, let reason):
            "Could not inspect Git changes in \(repositoryRoot): \(reason)"
        case .commandFailed(let repositoryRoot):
            "Git could not list changes in repository: \(repositoryRoot)"
        case .invalidStatusOutput(let repositoryRoot):
            "Git returned invalid changed-file data for: \(repositoryRoot)"
        }
    }
}
