import ArcaAnalysis
import ArcaDomain
import Testing

@Suite("Tight class cohesion calculator")
struct TightClassCohesionCalculatorTests {
    @Test("all method pairs sharing state are fully cohesive")
    func fullyCohesive() {
        let result = calculate(["a": ["state"], "b": ["state"]])

        #expect(result.value == 1)
        #expect(result.connectedPairCount == 1)
        #expect(result.possiblePairCount == 1)
    }

    @Test("one connected pair out of three produces one third")
    func partiallyCohesive() {
        let result = calculate([
            "a": ["session"],
            "b": ["session"],
            "c": ["invoices"]
        ])

        #expect(abs((result.value ?? 0) - (1.0 / 3.0)) < 0.000_001)
        #expect(result.connectedPairCount == 1)
        #expect(result.possiblePairCount == 3)
    }

    @Test("disjoint method state has zero cohesion")
    func noCohesion() {
        let result = calculate(["a": ["left"], "b": ["right"]])

        #expect(result.value == 0)
    }

    @Test("insufficient structure makes cohesion unavailable")
    func unavailableCohesion() {
        #expect(calculate(["a": ["state"]]).value == nil)
        #expect(calculate(["a": [], "b": []], properties: []).value == nil)
    }

    private func calculate(
        _ accesses: [String: Set<String>],
        properties: Set<String>? = nil
    ) -> TightClassCohesionResult {
        let methods = accesses.keys.sorted().map {
            MethodPropertyAccess(
                methodName: $0,
                range: SourceRange(
                    startLine: 1,
                    startColumn: 1,
                    endLine: 1,
                    endColumn: 1
                ),
                accessedStoredProperties: accesses[$0] ?? []
            )
        }
        return TightClassCohesionCalculator().calculate(
            methods: methods,
            storedProperties: properties
                ?? accesses.values.reduce(into: Set<String>()) {
                    $0.formUnion($1)
                }
        )
    }
}
