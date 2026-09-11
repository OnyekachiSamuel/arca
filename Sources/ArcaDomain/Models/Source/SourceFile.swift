import Foundation

public struct SourceFile: Codable, Equatable, Sendable {
    public let path: String
    public let content: String
    public let lineCount: Int

    public init(path: String, content: String, lineCount: Int) {
        self.path = path
        self.content = content
        self.lineCount = lineCount
    }
}
