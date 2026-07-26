import ArcanDomain
import Testing

@Suite("Review type")
struct ReviewTypeTests {
    @Test("command-line names use kebab case")
    func commandLineNames() {
        #expect(ReviewType.godObject.commandLineName == "god-object")
        #expect(
            ReviewType.tcaArchitecture.commandLineName == "tca-architecture"
        )
        #expect(ReviewType.style.commandLineName == "style")
        #expect(
            ReviewType.teamConvention.commandLineName == "team-convention"
        )
    }

    @Test("review types describe review concerns, not analyzer mechanisms")
    func excludesAnalyzerMechanisms() {
        #expect(
            Set(ReviewType.allCases) == [
                .godObject,
                .tcaArchitecture,
                .style,
                .teamConvention
            ]
        )
        #expect(ReviewType(commandLineName: "general-llm") == nil)
    }

    @Test("command-line names are converted to review types")
    func parsesCommandLineNames() {
        #expect(
            ReviewType(commandLineName: "god-object") == .godObject
        )
        #expect(
            ReviewType(commandLineName: "team-convention")
                == .teamConvention
        )
        #expect(ReviewType(commandLineName: "security") == nil)
    }
}
