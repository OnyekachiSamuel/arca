import ArcanDomain
import Foundation

public struct JSONReporter: Reporter {
    public init() {}

    public func render(report: ReviewReport) throws -> String {
        let data = try JSONEncoder().encode(report)
        return String(decoding: data, as: UTF8.self)
    }
}
