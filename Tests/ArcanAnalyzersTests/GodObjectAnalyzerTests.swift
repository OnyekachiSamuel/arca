import ArcanAnalysis
import ArcanAnalyzers
import ArcanDomain
import ArcanSource
import ArcanSwiftSyntax
import Foundation
import Testing

@Suite("God Object analyzer")
struct GodObjectAnalyzerTests {
    @Test("positive fixture produces one God Object finding")
    func detectsCandidateFixture() async throws {
        let source = try loadFixture(named: "GodObjectCandidate")
        let analyzer = GodObjectAnalyzer(
            thresholds: GodObjectThresholds(
                maximumLines: 8,
                maximumMethods: 2,
                maximumStoredProperties: 2
            ),
            structureProvider: SwiftSyntaxStructureProvider()
        )

        let result = try await analyzer.analyze(context: context(for: source))

        #expect(result.analyzerID == "god-object")
        #expect(result.findings.count == 1)
        #expect(result.findings.first?.ruleID == "ARCAN-GOD-001")
        #expect(result.findings.first?.filePath == source.path)
    }

    @Test("small fixture produces no finding")
    func ignoresNegativeFixture() async throws {
        let source = try loadFixture(named: "FocusedType")
        let structureProvider = SwiftSyntaxStructureProvider()
        let metrics = try structureProvider.extractMetrics(from: source)

        #expect(metrics.count == 1)
        #expect(metrics.first?.name == "FocusedService")

        let analyzer = GodObjectAnalyzer(
            thresholds: GodObjectThresholds(
                maximumLines: 8,
                maximumMethods: 2,
                maximumStoredProperties: 2
            ),
            structureProvider: structureProvider
        )

        let result = try await analyzer.analyze(context: context(for: source))

        #expect(result.findings.isEmpty)
    }

    @Test("values equal to thresholds do not trigger a finding")
    func thresholdBoundariesAreNotExceeded() async throws {
        let thresholds = GodObjectThresholds(
            maximumLines: 10,
            maximumMethods: 3,
            maximumStoredProperties: 2
        )
        let metrics = TypeStructuralMetrics(
            name: "BoundaryType",
            kind: .class,
            range: SourceRange(
                startLine: 1,
                startColumn: 1,
                endLine: 10,
                endColumn: 2
            ),
            lineCount: 10,
            methodCount: 3,
            propertyCount: 2
        )

        let result = try await analyze(metrics: [metrics], thresholds: thresholds)

        #expect(result.findings.isEmpty)
    }

    @Test("multiple signals are required by default")
    func requiresMultipleSignalsByDefault() async throws {
        let thresholds = GodObjectThresholds(
            maximumLines: 10,
            maximumMethods: 3,
            maximumStoredProperties: 2
        )
        let oneSignal = metrics(lineCount: 11, methodCount: 3, propertyCount: 2)
        let twoSignals = metrics(lineCount: 11, methodCount: 4, propertyCount: 2)

        let oneSignalResult = try await analyze(
            metrics: [oneSignal],
            thresholds: thresholds
        )
        let twoSignalResult = try await analyze(
            metrics: [twoSignals],
            thresholds: thresholds
        )

        #expect(oneSignalResult.findings.isEmpty)
        #expect(twoSignalResult.findings.count == 1)
    }

    @Test("required signal count is configurable")
    func supportsConfiguredSignalCount() async throws {
        let thresholds = GodObjectThresholds(
            maximumLines: 10,
            maximumMethods: 3,
            maximumStoredProperties: 2,
            minimumTriggeredSignals: 1
        )

        let result = try await analyze(
            metrics: [metrics(lineCount: 11, methodCount: 3, propertyCount: 2)],
            thresholds: thresholds
        )

        #expect(result.findings.count == 1)
    }

    private func analyze(
        metrics: [TypeStructuralMetrics],
        thresholds: GodObjectThresholds
    ) async throws -> AnalyzerResult {
        let source = SourceFile(
            path: "/tmp/Example.swift",
            content: "",
            lineCount: 0
        )
        let analyzer = GodObjectAnalyzer(
            thresholds: thresholds,
            structureProvider: StubStructureProvider(metrics: metrics)
        )
        return try await analyzer.analyze(context: context(for: source))
    }

    private func metrics(
        lineCount: Int,
        methodCount: Int,
        propertyCount: Int
    ) -> TypeStructuralMetrics {
        TypeStructuralMetrics(
            name: "Example",
            kind: .class,
            range: SourceRange(
                startLine: 1,
                startColumn: 1,
                endLine: lineCount,
                endColumn: 2
            ),
            lineCount: lineCount,
            methodCount: methodCount,
            propertyCount: propertyCount
        )
    }

    private func context(for source: SourceFile) -> AnalysisContext {
        AnalysisContext(
            request: ReviewRequest(id: UUID(), selectedFiles: [source.path]),
            sourceFiles: [source]
        )
    }

    private func loadFixture(named name: String) throws -> SourceFile {
        let url = try #require(
            Bundle.module.url(
                forResource: name,
                withExtension: "swift",
                subdirectory: "Fixtures"
            )
        )
        return try SwiftSourceFileLoader().load(path: url.path)
    }
}

private struct StubStructureProvider: SwiftStructureProvider {
    let metrics: [TypeStructuralMetrics]

    func extractMetrics(from sourceFile: SourceFile) throws -> [TypeStructuralMetrics] {
        metrics
    }
}
