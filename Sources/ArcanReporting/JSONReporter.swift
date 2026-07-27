import ArcanDomain
import Foundation

public struct JSONReporter: Reporter {
    public init() {}

    public func render(analysis: ReviewAnalysisResult) throws -> String {
        let data = try JSONEncoder().encode(analysis)
        return String(decoding: data, as: UTF8.self)
    }
}
