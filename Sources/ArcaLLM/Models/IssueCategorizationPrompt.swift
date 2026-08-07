public struct IssueCategorizationPrompt: Equatable, Sendable {
    public let templateID: String
    public let templateVersion: Int
    public let text: String

    public init(
        templateID: String,
        templateVersion: Int,
        text: String
    ) {
        self.templateID = templateID
        self.templateVersion = templateVersion
        self.text = text
    }
}
