import Foundation

public struct TypeStructuralMetrics: Codable, Equatable, Sendable {
    public let name: String
    public let kind: TypeKind
    public let sourcePath: String
    public let range: SourceRange
    public let lineCount: Int
    public let methodCount: Int
    public let propertyCount: Int
    public let tightClassCohesion: Double?
    public let cohesionEligibleMethodCount: Int
    public let cohesionConnectedPairCount: Int
    public let cohesionPossiblePairCount: Int

    public init(
        name: String,
        kind: TypeKind,
        sourcePath: String = "",
        range: SourceRange,
        lineCount: Int,
        methodCount: Int,
        propertyCount: Int,
        tightClassCohesion: Double? = nil,
        cohesionEligibleMethodCount: Int = 0,
        cohesionConnectedPairCount: Int = 0,
        cohesionPossiblePairCount: Int = 0
    ) {
        self.name = name
        self.kind = kind
        self.sourcePath = sourcePath
        self.range = range
        self.lineCount = lineCount
        self.methodCount = methodCount
        self.propertyCount = propertyCount
        self.tightClassCohesion = tightClassCohesion
        self.cohesionEligibleMethodCount = cohesionEligibleMethodCount
        self.cohesionConnectedPairCount = cohesionConnectedPairCount
        self.cohesionPossiblePairCount = cohesionPossiblePairCount
    }
}
