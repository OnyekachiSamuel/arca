@testable import ArcanAnalysis

enum TestAnalyzerClock {
    static func make(milliseconds: [Int]) -> AnalyzerClock {
        let origin = ContinuousClock().now
        let source = StubAnalyzerClock(
            instants: milliseconds.map {
                origin.advanced(by: .milliseconds($0))
            }
        )
        return AnalyzerClock(now: {
            await source.next()
        })
    }
}

private actor StubAnalyzerClock {
    private var instants: [ContinuousClock.Instant]

    init(instants: [ContinuousClock.Instant]) {
        self.instants = instants
    }

    func next() -> ContinuousClock.Instant {
        guard !instants.isEmpty else {
            preconditionFailure("The analyzer clock was read unexpectedly.")
        }
        return instants.removeFirst()
    }
}
