import ArcanDomain
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
            configuration: ArcanConfiguration(
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
        let suggestion = Suggestion(
            summary: "Split networking from presentation logic.",
            steps: ["Extract an API client", "Move view state into a view model"]
        )
        let finding = Finding(
            id: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
            ruleID: "ARCAN-GOD-001",
            externalRuleID: "type_body_length",
            title: "God Object candidate",
            category: .antiPattern,
            severity: .warning,
            filePath: "Sources/LargeCoordinator.swift",
            range: SourceRange(
                startLine: 1,
                startColumn: 1,
                endLine: 30,
                endColumn: 2
            ),
            explanation: "The type has too many responsibilities.",
            evidence: [
                Evidence(
                    metric: "methods",
                    observedValue: 30,
                    thresholdValue: 25
                )
            ],
            suggestion: suggestion,
            sources: ["god-object", "llm.general"],
            metadata: [
                "typeName": .string("LargeCoordinator"),
                "lineCount": .integer(30),
                "isExtension": .boolean(false),
                "score": .decimal(0.75)
            ]
        )
        let analyzerResult = AnalyzerResult(
            analyzerID: "god-object",
            findings: [finding],
            tool: ToolMetadata(name: "SwiftLint", version: "0.63.2"),
            durationMilliseconds: 17
        )
        let report = ReviewReport(
            schemaVersion: ReviewReport.currentSchemaVersion,
            requestID: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
            findings: [finding],
            analyzerResults: [analyzerResult]
        )

        let data = try encodeToJSON(report)
        
        let decoded = try decodeFromJSON(ReviewReport.self, from: data)

        #expect(decoded == report)
        #expect(decoded.findings.first?.externalRuleID == "type_body_length")
        #expect(decoded.findings.first?.suggestion == suggestion)
        #expect(decoded.findings.first?.category == .antiPattern)
        #expect(
            decoded.findings.first?.sources
                == ["god-object", "llm.general"]
        )
        #expect(
            decoded.findings.first?.metadata["lineCount"] == .integer(30)
        )
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

    @Test("legacy finding defaults category and metadata")
    func legacyFindingDefaults() throws {
        let data = Data(
            """
            {
              "id": "11111111-2222-3333-4444-555555555555",
              "ruleID": "legacy-rule",
              "title": "Legacy finding",
              "severity": "warning",
              "filePath": "Sources/App.swift",
              "explanation": "Created before normalized finding fields.",
              "evidence": []
            }
            """.utf8
        )

        let finding = try decodeFromJSON(Finding.self, from: data)

        #expect(finding.category == .uncategorized)
        #expect(finding.sources.isEmpty)
        #expect(finding.metadata.isEmpty)
    }

    @Test("legacy analyzer result without duration defaults to zero")
    func legacyAnalyzerResultDuration() throws {
        let data = Data(
            """
            {
              "analyzerID": "legacy",
              "findings": []
            }
            """.utf8
        )

        let decoded = try decodeFromJSON(AnalyzerResult.self, from: data)

        #expect(decoded.durationMilliseconds == 0)
        #expect(decoded.tool == nil)
        #expect(decoded.executionStatus == .completed)
        #expect(decoded.diagnostics.isEmpty)
    }

    @Test("skipped analyzer result preserves its diagnostic")
    func skippedAnalyzerResult() throws {
        let result = AnalyzerResult(
            analyzerID: "swiftlint",
            findings: [],
            tool: ToolMetadata(name: "SwiftLint"),
            executionStatus: .skipped,
            diagnostics: [
                AnalyzerDiagnostic(
                    code: "ARCAN-SWIFTLINT-UNAVAILABLE",
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
                == "ARCAN-SWIFTLINT-UNAVAILABLE"
        )
    }

    @Test("source context window encoding and decoding of values")
    func sourceContextWindow() throws {
        let context = SourceContextWindow(
            filePath: "Sources/App.swift",
            changedLineRange: ChangedLineRange(startLine: 10, endLine: 11),
            includedLineRange: SourceLineRange(startLine: 7, endLine: 14),
            sourceText: "func update() {}",
            containingType: TypeStructuralMetrics(
                name: "App",
                kind: .class,
                range: SourceRange(
                    startLine: 1,
                    startColumn: 1,
                    endLine: 30,
                    endColumn: 2
                ),
                lineCount: 30,
                methodCount: 4,
                propertyCount: 3
            )
        )

        let data = try encodeToJSON(context)
        let decoded = try decodeFromJSON(SourceContextWindow.self, from: data)

        #expect(decoded == context)
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
