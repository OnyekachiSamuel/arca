import Foundation

struct SwiftLintViolation: Decodable, Sendable {
    let ruleID: String
    let reason: String
    let line: Int?
    let character: Int?
    let severity: String
    let type: String
    let file: String

    private enum CodingKeys: String, CodingKey {
        case ruleID = "rule_id"
        case reason
        case line
        case character
        case severity
        case type
        case file
    }
}
