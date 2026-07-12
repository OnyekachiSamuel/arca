import ArcanDomain

public protocol SwiftStructureProvider: Sendable {
    func extractMetrics(
        from sourceFile: SourceFile
    ) throws -> [TypeStructuralMetrics]
}
