import ArcanDomain
import Foundation
import Testing

@Suite("Domain model JSON encoding and decoding")
struct DomainModelCodableTests {
    @Test("review request encoding and decoding of values")
    func reviewRequest() throws {
        let request = ReviewRequest(
            id: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
            selectedFiles: ["Sources/App.swift", "Sources/Feature.swift"]
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
            title: "God Object candidate",
            severity: .warning,
            filePath: "Sources/LargeCoordinator.swift",
            explanation: "The type has too many responsibilities.",
            suggestion: suggestion
        )
        let analyzerResult = AnalyzerResult(
            analyzerID: "god-object",
            findings: [finding]
        )
        let report = ReviewReport(
            schemaVersion: 1,
            requestID: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
            findings: [finding],
            analyzerResults: [analyzerResult]
        )

        let data = try encodeToJSON(report)
        
        let decoded = try decodeFromJSON(ReviewReport.self, from: data)

        #expect(decoded == report)
        #expect(decoded.findings.first?.suggestion == suggestion)
        #expect(decoded.analyzerResults.first == analyzerResult)
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
