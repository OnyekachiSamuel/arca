struct AnalyzerClock: Sendable {
    static let continuous = AnalyzerClock(now: {
        ContinuousClock().now
    })

    let now: @Sendable () async -> ContinuousClock.Instant
}
