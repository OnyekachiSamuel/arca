import ArcanDomain
import Testing

@Suite("Finding assessment")
struct FindingAssessmentTests {
    @Test("assessment values define the categorization contract")
    func exposesSupportedValues() {
        #expect(
            FindingAssessment.allCases.map(\.rawValue) == [
                "confirmed",
                "rejected",
                "uncertain"
            ]
        )
    }
}
