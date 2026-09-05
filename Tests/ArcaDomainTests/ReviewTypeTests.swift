import ArcaDomain
import Testing

@Suite("Review type")
struct ReviewTypeTests {
  @Test("LLM review types use stable command-line names")
  func commandLineNames() {
    #expect(ReviewType.swift.commandLineName == "swift")
    #expect(ReviewType.swiftUI.commandLineName == "swiftui")
    #expect(ReviewType.tca.commandLineName == "tca")
    #expect(ReviewType.security.commandLineName == "security")
    #expect(ReviewType.godObject.commandLineName == "god-object")
    #expect(ReviewType.all.commandLineName == "all")
  }

  @Test("only the LLM-only MVP review types are available")
  func availableReviewTypes() {
    #expect(
      ReviewType.analysisTypes == [
        .swift, .swiftUI, .tca, .security, .godObject,
      ])
  }

  @Test("removed review types are rejected")
  func rejectsRemovedReviewTypes() {
    #expect(ReviewType(commandLineName: "style") == nil)
    #expect(ReviewType(commandLineName: "team-convention") == nil)
    #expect(ReviewType(commandLineName: "tca-architecture") == nil)
  }

  @Test("command-line names are converted to review types")
  func parsesCommandLineNames() {
    #expect(ReviewType(commandLineName: "swift") == .swift)
    #expect(ReviewType(commandLineName: "swiftui") == .swiftUI)
    #expect(ReviewType(commandLineName: "tca") == .tca)
    #expect(ReviewType(commandLineName: "security") == .security)
    #expect(ReviewType(commandLineName: "god-object") == .godObject)
    #expect(ReviewType(commandLineName: "all") == .all)
  }
}
