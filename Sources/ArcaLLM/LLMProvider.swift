public protocol LLMProvider: Sendable {
    var id: String { get }

    func submit(_ request: LLMRequest) async throws -> LLMResponse
}
