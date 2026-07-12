import Foundation

public struct TypeStructuralMetrics: Codable, Equatable, Sendable {
    public let name: String
    public let kind: TypeKind
    public let range: SourceRange
    public let lineCount: Int
    public let methodCount: Int
    public let propertyCount: Int

    public init(
        name: String,
        kind: TypeKind,
        range: SourceRange,
        lineCount: Int,
        methodCount: Int,
        propertyCount: Int
    ) {
        self.name = name
        self.kind = kind
        self.range = range
        self.lineCount = lineCount
        self.methodCount = methodCount
        self.propertyCount = propertyCount
    }
}
