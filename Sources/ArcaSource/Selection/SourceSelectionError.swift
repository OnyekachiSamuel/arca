import Foundation

public enum SourceSelectionError: Equatable, LocalizedError {
    case missing(path: String)
    case directory(path: String)
    case notSwiftFile(path: String)
    case unreadable(path: String)

    public var errorDescription: String? {
        switch self {
        case .missing(let path):
            "Swift file does not exist: \(path)"
        case .directory(let path):
            "Expected a Swift file but found a directory: \(path)"
        case .notSwiftFile(let path):
            "Expected a file with a .swift extension: \(path)"
        case .unreadable(let path):
            "Swift file is not readable: \(path)"
        }
    }
}
