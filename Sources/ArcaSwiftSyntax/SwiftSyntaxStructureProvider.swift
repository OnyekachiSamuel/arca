import ArcaAnalysis
import ArcaDomain
import SwiftParser
import SwiftSyntax

public struct SwiftSyntaxStructureProvider: SwiftStructureProvider {
    public init() {}

    public func extractMetrics(
        from sourceFile: SourceFile
    ) throws -> [TypeStructuralMetrics] {
        extractFragments(from: sourceFile)
            .map { makeMetrics(from: [$0]) }
            .sorted { ($0.range.startLine, $0.name) <
                ($1.range.startLine, $1.name) }
    }

    public func extractMetrics(
        from sourceFiles: [SourceFile]
    ) throws -> [TypeStructuralMetrics] {
        let fragments = sourceFiles.flatMap(extractFragments)
        return Dictionary(grouping: fragments, by: \.identity)
            .values
            .map(makeMetrics)
            .sorted { ($0.sourcePath, $0.range.startLine, $0.name) <
                ($1.sourcePath, $1.range.startLine, $1.name) }
    }

    private func extractFragments(
        from sourceFile: SourceFile
    ) -> [TypeStructuralFragment] {
        let syntaxTree = Parser.parse(source: sourceFile.content)
        let converter = SourceLocationConverter(
            fileName: sourceFile.path,
            tree: syntaxTree
        )
        let extractor = SwiftSourceCodeMetricsExtractor(
            converter: converter,
            sourcePath: sourceFile.path
        )
        extractor.walk(syntaxTree)
        return extractor.fragments
    }

    private func makeMetrics(
        from fragments: [TypeStructuralFragment]
    ) -> TypeStructuralMetrics {
        let primary = fragments.first { $0.kind != .extension }
            ?? fragments[0]
        let storedProperties = fragments.reduce(into: Set<String>()) {
            $0.formUnion($1.storedPropertyNames)
        }
        let methods = fragments.flatMap(\.cohesionMethods).map {
            MethodPropertyAccess(
                methodName: $0.methodName,
                range: $0.range,
                accessedStoredProperties: $0.accessedStoredProperties
                    .intersection(storedProperties)
            )
        }
        let cohesion = TightClassCohesionCalculator().calculate(
            methods: methods,
            storedProperties: storedProperties
        )
        return TypeStructuralMetrics(
            name: primary.name,
            kind: primary.kind,
            sourcePath: primary.sourcePath,
            range: primary.range,
            lineCount: fragments.reduce(0) { $0 + $1.lineCount },
            methodCount: fragments.reduce(0) { $0 + $1.methodCount },
            propertyCount: storedProperties.count,
            tightClassCohesion: cohesion.value,
            cohesionEligibleMethodCount: cohesion.eligibleMethodCount,
            cohesionConnectedPairCount: cohesion.connectedPairCount,
            cohesionPossiblePairCount: cohesion.possiblePairCount
        )
    }
}
