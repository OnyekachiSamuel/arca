import Foundation

public enum LLMServerProviderError: Error, Equatable, LocalizedError, Sendable {
    case invalidServerConfiguration
    case invalidRequest
    case requestEncodingFailed
    case requestTimedOut
    case transportFailure
    case unexpectedStatusCode(Int)
    case invalidResponse
    case missingResponseContent

    public var errorDescription: String? {
        switch self {
        case .invalidServerConfiguration:
            "The LLM server configuration is invalid."
        case .invalidRequest:
            "The LLM request is invalid."
        case .requestEncodingFailed:
            "The LLM server request could not be encoded."
        case .requestTimedOut:
            "The LLM server request timed out."
        case .transportFailure:
            "The LLM server could not be reached."
        case .unexpectedStatusCode(let statusCode):
            "The LLM server returned HTTP status \(statusCode)."
        case .invalidResponse:
            "The LLM server returned an invalid response."
        case .missingResponseContent:
            "The LLM server response did not contain generated text."
        }
    }
}
