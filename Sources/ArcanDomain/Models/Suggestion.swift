import Foundation

public struct Suggestion: Codable, Equatable, Sendable {
    public let summary: String
    public let steps: [String]
    public let codeExample: String?

    public init(
        summary: String,
        steps: [String],
        codeExample: String? = nil
    ) {
        self.summary = summary
        self.steps = steps
        self.codeExample = codeExample
    }
}
