import ArcanDomain
import Foundation
import Testing

@Suite("Finding candidate domain model")
struct FindingCandidateCodableTests {
    @Test("candidate data survives a JSON round trip")
    func candidateRoundTrip() throws {
        let candidate = try FindingCandidate(
            candidateID: UUID(
                uuidString: "11111111-2222-3333-4444-555555555555"
            )!,
            ruleID: "ARCAN-GOD-001",
            title: "God Object candidate",
            explanation: """
            AppCoordinator combines navigation, persistence and networking.
            """,
            filePath: "Sources/AppCoordinator.swift",
            range: SourceRange(
                startLine: 1,
                startColumn: 1,
                endLine: 420,
                endColumn: 2
            ),
            proposedSeverity: .warning,
            proposedCategory: .antiPattern,
            evidence: [
                .metric(
                    MetricEvidence(
                        metricName: "methodCount",
                        observedValue: 30,
                        thresholdValue: 15
                    )
                ),
                .sourceCode(
                    SourceCodeEvidence(
                        description: "The type performs persistence work.",
                        range: SourceRange(
                            startLine: 80,
                            startColumn: 5,
                            endLine: 83,
                            endColumn: 6
                        ),
                        excerpt: """
                        func save(_ value: String) {
                            cache[value] = value
                        }
                        """
                    )
                )
            ],
            sourceIdentifiers: ["god-object", "llm.general"],
            analyzerMetadata: [
                "typeName": .string("AppCoordinator"),
                "modelID": .string("qwen2.5-coder"),
                "confidence": .decimal(0.82)
            ]
        )

        let data = try JSONEncoder().encode(candidate)
        let decoded = try JSONDecoder().decode(
            FindingCandidate.self,
            from: data
        )

        #expect(decoded == candidate)
        #expect(decoded.id == candidate.candidateID)
        #expect(
            decoded.candidateID
                == UUID(
                    uuidString: "11111111-2222-3333-4444-555555555555"
                )
        )
    }

    @Test("evidence JSON identifies metric, analyzer and source-code variants")
    func evidenceKinds() throws {
        let evidence: [FindingEvidence] = [
            .metric(
                MetricEvidence(
                    metricName: "lineCount",
                    observedValue: 420,
                    thresholdValue: 300
                )
            ),
            .ratio(
                RatioEvidence(
                    metricName: "tightClassCohesion",
                    observedValue: 0.2,
                    thresholdValue: 0.33
                )
            ),
            .analyzer(
                AnalyzerEvidence(
                    description: "SwiftLint reported a force cast.",
                    externalRuleID: "force_cast",
                    range: nil
                )
            ),
            .sourceCode(
                SourceCodeEvidence(
                    description: "The method mixes unrelated operations.",
                    range: SourceRange(
                        startLine: 40,
                        startColumn: 1,
                        endLine: 48,
                        endColumn: 2
                    ),
                    excerpt: "func update() {\n    print(\"Grüße 👋\")\n}"
                )
            )
        ]

        let data = try JSONEncoder().encode(evidence)
        let objects = try #require(
            JSONSerialization.jsonObject(with: data)
                as? [[String: Any]]
        )
        let decoded = try JSONDecoder().decode(
            [FindingEvidence].self,
            from: data
        )

        #expect(objects.map { $0["kind"] as? String } == [
            "metric",
            "ratio",
            "analyzer",
            "sourceCode"
        ])
        #expect(decoded == evidence)
    }

    @Test("unlocated analyzer candidates remain representable")
    func unlocatedCandidateRoundTrip() throws {
        let candidate = try FindingCandidate(
            candidateID: UUID(),
            ruleID: "swiftlint.example",
            title: "Example",
            explanation: "External analyzer output.",
            filePath: "Sources/App.swift",
            range: nil,
            proposedSeverity: .warning,
            proposedCategory: .style,
            evidence: [
                .analyzer(AnalyzerEvidence(
                    description: "External analyzer output.",
                    externalRuleID: "example"
                ))
            ],
            sourceIdentifiers: ["swiftlint"]
        )

        let decoded = try JSONDecoder().decode(
            FindingCandidate.self,
            from: JSONEncoder().encode(candidate)
        )

        #expect(decoded == candidate)
        #expect(decoded.range == nil)
    }

    @Test("candidate requires at least one source identifier")
    func candidateRequiresSourceIdentifier() {
        #expect(
            throws: FindingCandidateValidationError
                .missingSourceIdentifiers
        ) {
            try makeCandidate(sourceIdentifiers: [])
        }
    }

    @Test("candidate requires at least one evidence item")
    func candidateRequiresEvidence() {
        #expect(
            throws: FindingCandidateValidationError.missingEvidence
        ) {
            try makeCandidate(evidence: [])
        }
    }

    @Test("candidate requires a valid one-based source range")
    func candidateRequiresValidRange() {
        #expect(
            throws: FindingCandidateValidationError.invalidSourceRange
        ) {
            try makeCandidate(
                range: SourceRange(
                    startLine: 0,
                    startColumn: 1,
                    endLine: 1,
                    endColumn: 1
                )
            )
        }
    }

    @Test("unknown evidence kinds do not decode")
    func unknownEvidenceKind() {
        let data = Data(
            """
            {
              "kind": "runtimeTrace",
              "description": "Observed at runtime."
            }
            """.utf8
        )

        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(FindingEvidence.self, from: data)
        }
    }

    private func makeCandidate(
        range: SourceRange = SourceRange(
            startLine: 1,
            startColumn: 1,
            endLine: 20,
            endColumn: 2
        ),
        evidence: [FindingEvidence] = [
            .metric(
                MetricEvidence(
                    metricName: "lineCount",
                    observedValue: 20,
                    thresholdValue: 10
                )
            )
        ],
        sourceIdentifiers: [String] = ["test-analyzer"]
    ) throws -> FindingCandidate {
        try FindingCandidate(
            candidateID: UUID(
                uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"
            )!,
            ruleID: "ARCAN-TEST-001",
            title: "Candidate",
            explanation: "Test explanation.",
            filePath: "Sources/App.swift",
            range: range,
            proposedSeverity: .warning,
            proposedCategory: .general,
            evidence: evidence,
            sourceIdentifiers: sourceIdentifiers
        )
    }
}
