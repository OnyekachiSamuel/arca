import Foundation

public enum ProcessExecutionError: Equatable, LocalizedError, Sendable {
    case executableURLMustBeAbsolute(String)
    case executableNotApproved(path: String)
    case executableNotFound(path: String)
    case executableNotRunnable(path: String)
    case invalidTimeout
    case invalidWorkingDirectory(path: String)
    case couldNotStart(path: String, reason: String)

    public var errorDescription: String? {
        switch self {
        case .executableURLMustBeAbsolute(let value):
            "Executable URL must be an absolute file URL: \(value)"
        case .executableNotApproved(let path):
            "Executable is not approved: \(path)"
        case .executableNotFound(let path):
            "Executable does not exist: \(path)"
        case .executableNotRunnable(let path):
            "File is not executable: \(path)"
        case .invalidTimeout:
            "Process timeout must be greater than zero."
        case .invalidWorkingDirectory(let path):
            "Process working directory does not exist: \(path)"
        case .couldNotStart(let path, let reason):
            "Could not start executable at \(path): \(reason)"
        }
    }
}
