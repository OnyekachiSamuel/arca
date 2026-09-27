import ArcaDomain
import Testing

@Suite("Review type")
struct ReviewTypeTests {
  @Test("only the LLM-only MVP review types are available")
  func availableReviewTypes() {
    #expect(
      ReviewType.analysisTypes == [
        .swift, .swiftUI, .tca, .security, .godObject,
      ])
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
