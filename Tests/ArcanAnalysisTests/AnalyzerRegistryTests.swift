import ArcanAnalysis
import ArcanDomain
import Testing

@Suite("Analyzer registry")
struct AnalyzerRegistryTests {
    @Test("registry selects only analyzers matching the requested review types")
    func selectsMatchingAnalyzers() {
        let registry = AnalyzerRegistry(analyzers: [
            RegistryTestAnalyzer(
                id: "god-object",
                supportedReviewTypes: [.godObject]
            ),
            RegistryTestAnalyzer(
                id: "style",
                supportedReviewTypes: [.style]
            ),
            RegistryTestAnalyzer(
                id: "shared",
                supportedReviewTypes: [.godObject, .style]
            )
        ])

        let selected = registry.analyzers(matching: [.godObject])

        #expect(selected.map { $0.id } == ["god-object", "shared"])
        #expect(
            registry.supportedReviewTypes == [.godObject, .style]
        )
    }

    @Test("one analyzer is selected once when it matches repeated review types")
    func doesNotDuplicateMatchingAnalyzer() {
        let registry = AnalyzerRegistry(analyzers: [
            RegistryTestAnalyzer(
                id: "shared",
                supportedReviewTypes: [.godObject, .style]
            )
        ])

        let selected = registry.analyzers(
            matching: [.godObject, .style]
        )

        #expect(selected.map { $0.id } == ["shared"])
    }

    @Test("review concerns select static and shared analysis strategies")
    func selectsStaticAndSharedStrategies() {
        let registry = AnalyzerRegistry(analyzers: [
            RegistryTestAnalyzer(
                id: "god-object",
                supportedReviewTypes: [.godObject]
            ),
            RegistryTestAnalyzer(
                id: "swiftlint",
                supportedReviewTypes: [.style]
            ),
            RegistryTestAnalyzer(
                id: "team-convention",
                supportedReviewTypes: [.teamConvention]
            ),
            RegistryTestAnalyzer(
                id: "llm-code-analysis",
                supportedReviewTypes: Set(ReviewType.allCases)
            )
        ])

        #expect(
            registry.analyzers(matching: [.godObject]).map(\.id)
                == ["god-object", "llm-code-analysis"]
        )
        #expect(
            registry.analyzers(matching: [.style]).map(\.id)
                == ["swiftlint", "llm-code-analysis"]
        )
        #expect(
            registry.analyzers(
                matching: [.godObject, .style, .teamConvention]
            ).map(\.id) == [
                "god-object",
                "swiftlint",
                "team-convention",
                "llm-code-analysis"
            ]
        )
    }
}

private struct RegistryTestAnalyzer: Analyzer {
    let id: String
    let supportedReviewTypes: Set<ReviewType>

    func analyze(context: AnalysisContext) async throws -> AnalyzerResult {
        AnalyzerResult(analyzerID: id, candidates: [])
    }
}
