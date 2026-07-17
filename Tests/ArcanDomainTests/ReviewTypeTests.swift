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
        #expect(ReviewType.generalLLM.commandLineName == "general-llm")
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
