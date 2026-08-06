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
        #expect(result.candidates.count == 1)
        let candidate = try #require(result.candidates.first)
        #expect(candidate.ruleID == "ARCAN-GOD-001")
        #expect(candidate.proposedCategory == .antiPattern)
        #expect(candidate.proposedSeverity == .warning)
        #expect(candidate.filePath == source.path)
        #expect(candidate.range == SourceRange(
            startLine: 1,
            startColumn: 1,
            endLine: 9,
            endColumn: 2
        ))
        #expect(candidate.evidence == [
            .metric(MetricEvidence(
                metricName: "lines", observedValue: 9, thresholdValue: 8
            )),
            .metric(MetricEvidence(
                metricName: "methods", observedValue: 3, thresholdValue: 2
            )),
            .metric(MetricEvidence(
                metricName: "storedProperties",
                observedValue: 3,
                thresholdValue: 2
            )),
            .ratio(RatioEvidence(
                metricName: "tightClassCohesion",
                observedValue: 0,
                thresholdValue: 0.33
            ))
        ])
        #expect(
            candidate.explanation
                == "Type 'LargeCoordinator' exceeds multiple configured structural thresholds and has low cohesion, suggesting it may have too many responsibilities."
        )
        #expect(candidate.sourceIdentifiers == ["god-object"])
        #expect(candidate.analyzerMetadata == [
            "typeName": .string("LargeCoordinator"),
            "typeKind": .string("class"),
            "lineCount": .integer(9),
            "methodCount": .integer(3),
            "propertyCount": .integer(3),
            "tightClassCohesion": .decimal(0),
            "cohesionEligibleMethodCount": .integer(3),
            "cohesionConnectedPairCount": .integer(0),
            "cohesionPossiblePairCount": .integer(3),
            "sourcePath": .string(source.path)
        ])
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

        #expect(result.candidates.isEmpty)
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

        #expect(result.candidates.isEmpty)
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

        #expect(oneSignalResult.candidates.isEmpty)
        #expect(twoSignalResult.candidates.count == 1)
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

        #expect(result.candidates.count == 1)
    }

    @Test("large cohesive types are not reported")
    func ignoresStructurallyLargeCohesiveType() async throws {
        let result = try await analyze(
            metrics: [metrics(
                lineCount: 20,
                methodCount: 5,
                propertyCount: 4,
                tightClassCohesion: 0.8
            )],
            thresholds: GodObjectThresholds(
                maximumLines: 10,
                maximumMethods: 3,
                maximumStoredProperties: 2
            )
        )

        #expect(result.candidates.isEmpty)
    }

    @Test("low cohesion must be strictly below its threshold")
    func cohesionThresholdBoundaryDoesNotTrigger() async throws {
        let result = try await analyze(
            metrics: [metrics(
                lineCount: 20,
                methodCount: 5,
                propertyCount: 4,
                tightClassCohesion: 0.33
            )],
            thresholds: GodObjectThresholds(
                maximumLines: 10,
                maximumMethods: 3,
                maximumStoredProperties: 2,
                minimumTightClassCohesion: 0.33
            )
        )

        #expect(result.candidates.isEmpty)
    }

    @Test("types without enough structure for cohesion are not reported")
    func unavailableCohesionDoesNotTrigger() async throws {
        let result = try await analyze(
            metrics: [metrics(
                lineCount: 20,
                methodCount: 5,
                propertyCount: 4,
                tightClassCohesion: nil
            )],
            thresholds: GodObjectThresholds(
                maximumLines: 10,
                maximumMethods: 3,
                maximumStoredProperties: 2
            )
        )

        #expect(result.candidates.isEmpty)
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
        propertyCount: Int,
        tightClassCohesion: Double? = 0
    ) -> TypeStructuralMetrics {
        TypeStructuralMetrics(
            name: "Example",
            kind: .class,
            sourcePath: "/tmp/Example.swift",
            range: SourceRange(
                startLine: 1,
                startColumn: 1,
                endLine: lineCount,
                endColumn: 2
            ),
            lineCount: lineCount,
            methodCount: methodCount,
            propertyCount: propertyCount,
            tightClassCohesion: tightClassCohesion,
            cohesionEligibleMethodCount: methodCount,
            cohesionConnectedPairCount: 0,
            cohesionPossiblePairCount: methodCount * (methodCount - 1) / 2
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
        return try SourceFileLoader().load(path: url.path)
    }
}

private struct StubStructureProvider: SwiftStructureProvider {
    let metrics: [TypeStructuralMetrics]

    func extractMetrics(from sourceFile: SourceFile) throws -> [TypeStructuralMetrics] {
        metrics
    }
}
