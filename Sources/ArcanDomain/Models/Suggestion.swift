import Foundation

public struct Suggestion: Codable, Equatable, Sendable {
    public let summary: String
    public let steps: [String]

    public init(summary: String, steps: [String]) {
        self.summary = summary
        self.steps = steps
    }
}
