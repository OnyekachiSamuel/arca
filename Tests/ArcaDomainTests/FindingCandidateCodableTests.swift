import ArcaDomain
import Foundation
import Testing

@Suite("Finding candidate domain model")
struct FindingCandidateCodableTests {
  @Test("LLM candidate data survives a JSON round trip")
  func candidateRoundTrip() throws {
    let candidate = try makeCandidate()
    let data = try JSONEncoder().encode(candidate)
    let decoded = try JSONDecoder().decode(FindingCandidate.self, from: data)
    let json = try #require(
      JSONSerialization.jsonObject(with: data) as? [String: Any]
    )

    #expect(decoded == candidate)
    #expect(json["issueType"] == nil)
    #expect(json["category"] == nil)
    #expect(decoded.evidence.first?.description == "The type owns unrelated behavior.")
  }

  @Test("candidate requires at least one source-code evidence item")
  func candidateRequiresEvidence() {
    #expect(throws: FindingCandidateValidationError.missingEvidence) {
      try makeCandidate(evidence: [])
    }
  }

  @Test("candidate requires a valid one-based source range")
  func candidateRequiresValidRange() {
    #expect(throws: FindingCandidateValidationError.invalidSourceRange) {
      try makeCandidate(
        range: SourceRange(
          startLine: 0,
          startColumn: 1,
          endLine: 1,
          endColumn: 1
        ))
    }
  }

  @Test("source evidence requires a valid one-based range")
  func candidateRequiresValidEvidenceRange() {
    #expect(throws: FindingCandidateValidationError.invalidEvidenceSourceRange) {
      try makeCandidate(evidence: [
        SourceCodeEvidence(
          description: "Invalid location.",
          range: SourceRange(
            startLine: 0,
            startColumn: 1,
            endLine: 1,
            endColumn: 1
          ),
          excerpt: "struct App {}"
        )
      ])
    }
  }

  private func makeCandidate(
    range: SourceRange = SourceRange(
      startLine: 1,
      startColumn: 1,
      endLine: 20,
      endColumn: 2
    ),
    evidence: [SourceCodeEvidence] = [
      SourceCodeEvidence(
        description: "The type owns unrelated behavior.",
        range: SourceRange(
          startLine: 2,
          startColumn: 1,
          endLine: 4,
          endColumn: 2
        ),
        excerpt: "func save() {}"
      )
    ]
  ) throws -> FindingCandidate {
    try FindingCandidate(
      ruleID: "ARCA-TEST-001",
      title: "Candidate",
      explanation: "Test explanation.",
      filePath: "Sources/App.swift",
      range: range,
      evidence: evidence
    )
  }
}
