import Foundation

public enum SourceContextProviderError: Equatable, LocalizedError {
    case invalidSurroundingLineCount(Int)
    case sourcePathMismatch(changePath: String, sourcePath: String)
    case invalidChangedLineRange(
        filePath: String,
        startLine: Int,
        endLine: Int,
        fileLineCount: Int
    )

    public var errorDescription: String? {
        switch self {
        case .invalidSurroundingLineCount(let count):
            "Surrounding line count cannot be negative: \(count)"
        case .sourcePathMismatch(let changePath, let sourcePath):
            "Code change path \(changePath) does not match source path \(sourcePath)"
        case .invalidChangedLineRange(
            let filePath,
            let startLine,
            let endLine,
            let fileLineCount
        ):
            "Changed line range \(startLine)-\(endLine) is outside "
                + "\(filePath), which has \(fileLineCount) lines"
        }
    }
}
