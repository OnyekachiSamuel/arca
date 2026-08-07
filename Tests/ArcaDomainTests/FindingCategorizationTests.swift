import ArcaDomain
import Foundation
import Testing

@Suite("Finding categorization")
struct FindingCategorizationTests {
    @Test("categorization models round-trip without compatibility defaults")
    func roundTrips() throws {
        let value = FindingCategorization(
            summary: "One issue was confirmed.",
            decisions: [FindingCategorizationDecision(
                candidateIDs: [
                    UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
                ],
                sourceIdentifiers: ["god-object"],
                assessment: .confirmed,
                category: .antiPattern,
                severity: .warning,
                canonicalRuleID: "ARCA-GOD-001",
                title: "God Object",
                rationale: "The evidence supports the issue."
            )]
        )

        let data = try JSONEncoder().encode(value)
        #expect(try JSONDecoder().decode(FindingCategorization.self, from: data) == value)

        let missingSummary = #"{"decisions":[]}"#.data(using: .utf8)!
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(
                FindingCategorization.self,
                from: missingSummary
            )
        }
    }
}
