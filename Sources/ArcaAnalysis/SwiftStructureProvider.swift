import ArcaDomain

public protocol SwiftStructureProvider: Sendable {
    func extractMetrics(
        from sourceFile: SourceFile
    ) throws -> [TypeStructuralMetrics]

    func extractMetrics(
        from sourceFiles: [SourceFile]
    ) throws -> [TypeStructuralMetrics]
}

public extension SwiftStructureProvider {
    func extractMetrics(
        from sourceFiles: [SourceFile]
    ) throws -> [TypeStructuralMetrics] {
        try sourceFiles.flatMap(extractMetrics(from:))
    }
}
