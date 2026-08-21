import ArcaDomain
import Foundation

public struct JSONReporter: Reporter {
    public init() {}

    public func render(analysis: ReviewAnalysisResult) throws -> String {
        try encode(analysis)
    }

    public func render(report: CategorizedReviewReport) throws -> String {
        try encode(report)
    }

    public func render(
        detectionReport: LLMIssueDetectionReport
    ) throws -> String {
        try encode(detectionReport)
    }

    private func encode(_ value: some Encodable) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(value)
        return String(decoding: data, as: UTF8.self)
    }
}
