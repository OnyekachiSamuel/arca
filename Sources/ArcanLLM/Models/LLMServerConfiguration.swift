import Foundation

public struct LLMServerConfiguration: Equatable, Sendable {
    public let providerID: String
    public let baseURL: URL
    public let completionPath: String
    public let apiKey: String?

    public init(
        providerID: String,
        baseURL: URL,
        completionPath: String = "/v1/chat/completions",
        apiKey: String? = nil
    ) {
        self.providerID = providerID
        self.baseURL = baseURL
        self.completionPath = completionPath
        self.apiKey = apiKey
    }
}
