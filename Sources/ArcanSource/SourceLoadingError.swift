import Foundation

public enum SourceLoadingError: Error, Equatable, LocalizedError {
    case unreadable(path: String)
    case invalidUTF8(path: String)

    public var errorDescription: String? {
        switch self {
        case .unreadable(let path):
            "Swift source file is not readable: \(path)"
        case .invalidUTF8(let path):
            "Swift source file is not valid UTF-8: \(path)"
        }
    }
}
