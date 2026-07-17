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
        let extractor = SwiftSourceCodeMetricsExtractor(converter: converter)
        extractor.walk(syntaxTree)
        return extractor.metrics
    }
}

