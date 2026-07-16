import Foundation

public enum GitRepositoryFinderError: Error, Equatable, LocalizedError {
    case notRepository(path: String)
    case commandCouldNotRun(path: String, reason: String)
    case invalidOutput(path: String)

    public var errorDescription: String? {
        switch self {
        case .notRepository(let path):
            "Path is not inside a Git repository: \(path)"
        case .commandCouldNotRun(let path, let reason):
            "Could not discover the Git repository for \(path): \(reason)"
        case .invalidOutput(let path):
            "Git returned an invalid repository root for: \(path)"
        }
    }
}
