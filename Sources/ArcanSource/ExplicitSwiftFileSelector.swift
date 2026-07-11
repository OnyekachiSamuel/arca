import Foundation



public struct ExplicitSwiftFileSelector: Sendable {
    public init() {}

    public func select(path: String) throws -> String {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(
            atPath: path,
            isDirectory: &isDirectory
        ) else {
            throw SourceSelectionError.missing(path: path)
        }

        guard !isDirectory.boolValue else {
            throw SourceSelectionError.directory(path: path)
        }

        guard URL(fileURLWithPath: path).pathExtension.lowercased() == "swift" else {
            throw SourceSelectionError.notSwiftFile(path: path)
        }

        guard FileManager.default.isReadableFile(atPath: path) else {
            throw SourceSelectionError.unreadable(path: path)
        }

        return path
    }
}
