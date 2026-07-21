import Foundation

public enum FindingNormalizationError: Error, Equatable, LocalizedError {
    case invalidRange(filePath: String)

    public var errorDescription: String? {
        switch self {
        case .invalidRange(let filePath):
            "Finding has an invalid source range for: \(filePath)"
        }
    }
}
