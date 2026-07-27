import ArcanDomain

public struct AnalyzerRunner: Sendable {
    private let clock: AnalyzerClock

    public init() {
        clock = .continuous
    }

    init(clock: AnalyzerClock) {
        self.clock = clock
    }

    public func run(
        _ analyzer: any Analyzer,
        context: AnalysisContext
    ) async throws -> AnalyzerResult {
        let start = await clock.now()
        let result = try await analyzer.analyze(context: context)
        let end = await clock.now()

        return AnalyzerResult(
            analyzerID: result.analyzerID,
            findings: result.findings,
            candidates: result.candidates,
            tool: result.tool,
            executionStatus: result.executionStatus,
            diagnostics: result.diagnostics,
            durationMilliseconds: durationInMilliseconds(
                from: start,
                to: end
            ),
            llmExecutionMetadata: result.llmExecutionMetadata
        )
    }

    public func run(
        _ analyzers: [any Analyzer],
        context: AnalysisContext
    ) async throws -> [AnalyzerResult] {
        var results: [AnalyzerResult] = []

        for analyzer in analyzers {
            results.append(
                try await run(analyzer, context: context)
            )
        }

        return results
    }

    private func durationInMilliseconds(
        from start: ContinuousClock.Instant,
        to end: ContinuousClock.Instant
    ) -> Int {
        let components = start.duration(to: end).components
        let milliseconds =
            components.seconds * 1_000
            + components.attoseconds / 1_000_000_000_000_000
        return max(0, Int(milliseconds))
    }
}
