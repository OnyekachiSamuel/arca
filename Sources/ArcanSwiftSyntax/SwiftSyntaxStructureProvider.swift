import ArcanAnalysis
import ArcanDomain
import SwiftParser
import SwiftSyntax

public struct SwiftSyntaxStructureProvider: SwiftStructureProvider {
    public init() {}

    public func extractMetrics(
        from sourceFile: SourceFile
    ) throws -> [TypeStructuralMetrics] {
        let syntaxTree = Parser.parse(source: sourceFile.content)
        let converter = SourceLocationConverter(
            fileName: sourceFile.path,
            tree: syntaxTree
        )
        let visitor = StructuralMetricsVisitor(converter: converter)
        visitor.walk(syntaxTree)
        return visitor.metrics
    }
}

