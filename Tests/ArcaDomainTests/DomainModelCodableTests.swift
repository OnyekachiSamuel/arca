import ArcaDomain
import Foundation
import Testing

@Suite("Domain model JSON encoding and decoding")
struct DomainModelCodableTests {
    @Test("review request encoding and decoding of values")
    func reviewRequest() throws {
        let request = ReviewRequest(
            id: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
            repositoryRoot: "/Users/developer/Project",
            selectedFiles: ["Sources/App.swift", "Sources/Feature.swift"],
            changes: [
                CodeChange(
                    filePath: "Sources/App.swift",
                    addedLineRanges: [
                        ChangedLineRange(startLine: 8, endLine: 10)
                    ],
                    modifiedLineRanges: [
                        ChangedLineRange(startLine: 20, endLine: 21)
                    ],
                    deletedLineRanges: [
                        DeletedLineRange(
                            originalStartLine: 15,
                            originalEndLine: 16
                        )
                    ]
                )
            ],
            selectedReviewTypes: [.godObject, .style],
            configuration: ArcaConfiguration(
                schemaVersion: 1,
                godObjectThresholds: GodObjectThresholds(
                    maximumLines: 300,
                    maximumMethods: 15,
                    maximumStoredProperties: 12,
                    minimumTriggeredSignals: 3
                )
            )
        )

        let data = try encodeToJSON(request)
        let decoded = try decodeFromJSON(ReviewRequest.self, from: data)

        #expect(decoded == request)
    }

    @Test("review report encoding and decoding of values")
    func reviewReport() throws {
        let candidateID = UUID(
            uuidString: "11111111-2222-3333-4444-555555555555"
        )!
        let candidate = try FindingCandidate(
            candidateID: candidateID,
            ruleID: "ARCA-GOD-001",
            title: "God Object candidate",
            explanation: "The type has too many responsibilities.",
            filePath: "Sources/LargeCoordinator.swift",
            range: SourceRange(
                startLine: 1,
                startColumn: 1,
                endLine: 30,
                endColumn: 2
            ),
            proposedSeverity: .warning,
            proposedCategory: .antiPattern,
            evidence: [.metric(MetricEvidence(
                metricName: "methods",
                observedValue: 30,
                thresholdValue: 25
            ))],
            sourceIdentifiers: ["god-object"]
        )
        let finding = Finding(
            id: candidateID,
            candidateIDs: [candidateID],
            assessment: .confirmed,
            ruleID: "ARCA-GOD-001",
            title: "God Object",
            category: .antiPattern,
            severity: .warning,
            classificationRationale: "The evidence supports the issue.",
            sources: ["god-object"],
            candidates: [candidate]
        )
        let analyzerResult = AnalyzerResult(
            analyzerID: "god-object",
            candidates: [],
            tool: ToolMetadata(name: "SwiftLint", version: "0.63.2"),
            durationMilliseconds: 17
        )
        let report = CategorizedReviewReport(
            schemaVersion: CategorizedReviewReport.currentSchemaVersion,
            requestID: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
            categorizationSummary: "One issue was confirmed.",
            confirmedFindings: [finding],
            uncertainFindings: [],
            candidates: [candidate],
            categorizationDecisions: [],
            counts: ReviewReportCounts(
                totalCandidates: 1,
                confirmed: 1,
                rejected: 0,
                uncertain: 0,
                findingsPerCategory: [
                    CategoryFindingCount(category: .antiPattern, count: 1)
                ]
            ),
            diagnostics: [],
            analyzerResults: [analyzerResult],
            categorizationExecutionMetadata: LLMExecutionMetadata(
                providerID: "ollama",
                modelID: "qwen",
                requestCount: 1,
                providerDurationMilliseconds: 10
            )
        )

        let data = try encodeToJSON(report)
        
        let decoded = try decodeFromJSON(
            CategorizedReviewReport.self,
            from: data
        )

        #expect(decoded == report)
        #expect(decoded.schemaVersion == 1)
        #expect(decoded.confirmedFindings.first?.category == .antiPattern)
        #expect(decoded.confirmedFindings.first?.candidates == [candidate])
        #expect(
            decoded.analyzerResults.first?.tool
                == ToolMetadata(name: "SwiftLint", version: "0.63.2")
        )
        #expect(decoded.analyzerResults.first == analyzerResult)
    }

    @Test("finding metadata values encode as JSON scalar values")
    func findingMetadataScalars() throws {
        let values: [String: FindingMetadataValue] = [
            "string": .string("value"),
            "integer": .integer(8),
            "decimal": .decimal(1.5),
            "boolean": .boolean(true)
        ]

        let data = try encodeToJSON(values)
        let object = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        let decoded = try decodeFromJSON(
            [String: FindingMetadataValue].self,
            from: data
        )

        #expect(object["string"] as? String == "value")
        #expect(object["integer"] as? Int == 8)
        #expect(object["decimal"] as? Double == 1.5)
        #expect(object["boolean"] as? Bool == true)
        #expect(decoded == values)
    }

    @Test("analyzer result requires the candidate contract")
    func analyzerResultRequiresCandidates() throws {
        let data = Data(
            """
            {
              "analyzerID": "invalid",
              "tool": null,
              "executionStatus": "completed",
              "diagnostics": [],
              "durationMilliseconds": 0,
              "llmExecutionMetadata": null
            }
            """.utf8
        )

        #expect(throws: DecodingError.self) {
            try decodeFromJSON(AnalyzerResult.self, from: data)
        }
    }

    @Test("LLM analyzer candidates and execution metadata round trip")
    func llmAnalyzerResultRoundTrip() throws {
        let candidate = try FindingCandidate(
            candidateID: UUID(
                uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"
            )!,
            ruleID: "ARCA-GOD-001",
            title: "God Object candidate",
            explanation: "The type has unrelated responsibilities.",
            filePath: "Sources/App.swift",
            range: SourceRange(
                startLine: 1,
                startColumn: 1,
                endLine: 3,
                endColumn: 2
            ),
            proposedSeverity: .warning,
            proposedCategory: .antiPattern,
            evidence: [
                .sourceCode(SourceCodeEvidence(
                    description: "Several responsibilities are present.",
                    range: SourceRange(
                        startLine: 1,
                        startColumn: 1,
                        endLine: 3,
                        endColumn: 2
                    ),
                    excerpt: "struct App {}"
                ))
            ],
            sourceIdentifiers: [
                "llm-code-analysis",
                "llm-provider:ollama",
                "llm-model:qwen"
            ]
        )
        let result = AnalyzerResult(
            analyzerID: "llm-code-analysis",
            candidates: [candidate],
            llmExecutionMetadata: LLMExecutionMetadata(
                providerID: "ollama",
                modelID: "qwen",
                requestCount: 2,
                usage: LLMTokenUsageMetadata(
                    inputTokens: 100,
                    outputTokens: 20,
                    totalTokens: 120
                ),
                providerDurationMilliseconds: 45
            )
        )

        let decoded = try decodeFromJSON(
            AnalyzerResult.self,
            from: encodeToJSON(result)
        )

        #expect(decoded == result)
    }

    @Test("review analysis requires candidates in its serialized contract")
    func reviewAnalysisRequiresCandidates() {
        let data = Data(
            """
            {
              "schemaVersion": 1,
              "requestID": "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE",
              "analyzerResults": [],
              "diagnostics": []
            }
            """.utf8
        )

        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(ReviewAnalysisResult.self, from: data)
        }
    }

    @Test("skipped analyzer result preserves its diagnostic")
    func skippedAnalyzerResult() throws {
        let result = AnalyzerResult(
            analyzerID: "swiftlint",
            candidates: [],
            tool: ToolMetadata(name: "SwiftLint"),
            executionStatus: .skipped,
            diagnostics: [
                AnalyzerDiagnostic(
                    code: "ARCA-SWIFTLINT-UNAVAILABLE",
                    severity: .warning,
                    message: "SwiftLint was not found."
                )
            ]
        )

        let decoded = try decodeFromJSON(
            AnalyzerResult.self,
            from: encodeToJSON(result)
        )

        #expect(decoded == result)
        #expect(decoded.executionStatus == .skipped)
        #expect(
            decoded.diagnostics.first?.code
                == "ARCA-SWIFTLINT-UNAVAILABLE"
        )
    }

    @Test(
        "severity values encoding and decoding",
        arguments: Severity.allCases
    )
    func severity(severity: Severity) throws {
        let data = try encodeToJSON(severity)
        #expect(try decodeFromJSON(Severity.self, from: data) == severity)
    }
    
    private func encodeToJSON<Value: Encodable>(_ value: Value) throws -> Data {
        try JSONEncoder().encode(value)
    }

    private func decodeFromJSON<Value: Decodable>(
        _ type: Value.Type,
        from data: Data
    ) throws -> Value {
        try JSONDecoder().decode(type, from: data)
    }
}
