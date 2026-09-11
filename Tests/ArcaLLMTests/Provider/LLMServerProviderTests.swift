import ArcaDomain
@testable import ArcaLLM
import Foundation
import Testing

@Suite("LLM server provider")
struct LLMServerProviderTests {
    @Test("maps an LLM request and successful server response")
    func mapsRequestAndResponse() async throws {
        let recorder = HTTPRequestRecorder()
        let configuration = LLMServerConfiguration(
            providerID: "local-qwen",
            baseURL: try #require(URL(string: "http://127.0.0.1:8080")),
            completionPath: "/v1/chat/completions"
        )
        let provider = LLMServerProvider(
            configuration: configuration,
            sendRequest: { request in
                await recorder.record(request)
                return (
                    Data(
                        """
                        {
                          "choices": [
                            {
                              "message": {
                                "content": "{\\"summary\\":\\"Extract networking\\",\\"steps\\":[\\"Create an API client\\"]}"
                              }
                            }
                          ],
                          "usage": {
                            "prompt_tokens": 120,
                            "completion_tokens": 35,
                            "total_tokens": 155
                          }
                        }
                        """.utf8
                    ),
                    makeHTTPResponse(for: request, statusCode: 200)
                )
            }
        )
        let request = LLMRequest(
            modelID: "qwen2.5-coder",
            prompt: "Build one structured analysis response.",
            timeout: .seconds(12),
            seed: 42,
            temperature: 0.2
        )

        let response = try await provider.submit(request)
        let sentRequest = try #require(await recorder.lastRequest)
        let body = try requestBody(from: sentRequest)
        let messages = try #require(body["messages"] as? [[String: Any]])

        #expect(provider.id == "local-qwen")
        #expect(
            sentRequest.url?.absoluteString
                == "http://127.0.0.1:8080/v1/chat/completions"
        )
        #expect(sentRequest.httpMethod == "POST")
        #expect(
            sentRequest.value(forHTTPHeaderField: "Content-Type")
                == "application/json"
        )
        #expect(
            sentRequest.value(forHTTPHeaderField: "Authorization") == nil
        )
        #expect(sentRequest.timeoutInterval == 12)
        #expect(body["model"] as? String == "qwen2.5-coder")
        #expect(body["stream"] as? Bool == false)
        #expect(body["seed"] as? Int == 42)
        #expect(body["temperature"] as? Double == 0.2)
        #expect(messages.count == 1)
        #expect(messages.first?["role"] as? String == "user")
        #expect(
            messages.first?["content"] as? String
                == "Build one structured analysis response."
        )
        #expect(
            response.text
                == #"{"summary":"Extract networking","steps":["Create an API client"]}"#
        )
        #expect(response.usage.inputTokens == 120)
        #expect(response.usage.outputTokens == 35)
        #expect(response.usage.totalTokens == 155)
        #expect(response.durationMilliseconds >= 0)
    }

    @Test("adds optional authentication and omits absent generation settings")
    func mapsOptionalFields() async throws {
        let recorder = HTTPRequestRecorder()
        let configuration = LLMServerConfiguration(
            providerID: "secured-server",
            baseURL: try #require(URL(string: "https://models.example.test")),
            completionPath: "/chat",
            apiKey: "test-api-key"
        )
        let provider = LLMServerProvider(
            configuration: configuration,
            sendRequest: { request in
                await recorder.record(request)
                return (
                    Data(
                        """
                        {
                          "choices": [
                            {"message": {"content": "response"}}
                          ]
                        }
                        """.utf8
                    ),
                    makeHTTPResponse(for: request, statusCode: 200)
                )
            }
        )

        let response = try await provider.submit(
            LLMRequest(
                modelID: "frontier-model",
                prompt: "Prompt",
                timeout: .seconds(5)
            )
        )
        let sentRequest = try #require(await recorder.lastRequest)
        let body = try requestBody(from: sentRequest)

        #expect(
            sentRequest.value(forHTTPHeaderField: "Authorization")
                == "Bearer test-api-key"
        )
        #expect(body["seed"] == nil)
        #expect(body["temperature"] == nil)
        #expect(response.text == "response")
        #expect(response.usage == LLMTokenUsageMetadata())
    }

    @Test("reports non-successful HTTP status")
    func rejectsHTTPFailure() async {
        let provider = makeProvider { request in
            (
                Data("service unavailable".utf8),
                makeHTTPResponse(for: request, statusCode: 503)
            )
        }

        await expectProviderError(.unexpectedStatusCode(503)) {
            _ = try await provider.submit(makeRequest())
        }
    }

    @Test("reports malformed and incomplete response payloads")
    func rejectsInvalidResponses() async {
        let malformedProvider = makeProvider { request in
            (
                Data("not JSON".utf8),
                makeHTTPResponse(for: request, statusCode: 200)
            )
        }
        let missingContentProvider = makeProvider { request in
            (
                Data(#"{"choices":[]}"#.utf8),
                makeHTTPResponse(for: request, statusCode: 200)
            )
        }

        await expectProviderError(.invalidResponse) {
            _ = try await malformedProvider.submit(makeRequest())
        }
        await expectProviderError(.missingResponseContent) {
            _ = try await missingContentProvider.submit(makeRequest())
        }
    }

    @Test("reports timeout and transport failures without exposing credentials")
    func reportsTransportFailures() async {
        let timeoutProvider = makeProvider { _ in
            throw URLError(.timedOut)
        }
        let transportProvider = LLMServerProvider(
            configuration: LLMServerConfiguration(
                providerID: "secured-server",
                baseURL: URL(string: "https://models.example.test")!,
                completionPath: "/chat",
                apiKey: "must-not-appear"
            ),
            sendRequest: { _ in
                throw URLError(.cannotConnectToHost)
            }
        )

        await expectProviderError(.requestTimedOut) {
            _ = try await timeoutProvider.submit(makeRequest())
        }
        await expectProviderError(.transportFailure) {
            _ = try await transportProvider.submit(makeRequest())
        }

        #expect(
            !LLMServerProviderError.transportFailure.localizedDescription
                .contains("must-not-appear")
        )
    }

    @Test("rejects invalid server and request configuration before transport")
    func validatesConfigurationAndRequest() async {
        let invalidSchemeProvider = LLMServerProvider(
            configuration: LLMServerConfiguration(
                providerID: "invalid",
                baseURL: URL(string: "file:///tmp/model")!,
                completionPath: "/chat"
            ),
            sendRequest: { _ in
                Issue.record("Transport must not be invoked.")
                throw URLError(.unknown)
            }
        )
        let validProvider = makeProvider { request in
            (
                Data(),
                makeHTTPResponse(for: request, statusCode: 200)
            )
        }

        await expectProviderError(.invalidServerConfiguration) {
            _ = try await invalidSchemeProvider.submit(makeRequest())
        }
        await expectProviderError(.invalidRequest) {
            _ = try await validProvider.submit(
                LLMRequest(
                    modelID: "",
                    prompt: "Prompt",
                    timeout: .seconds(5)
                )
            )
        }
        await expectProviderError(.invalidRequest) {
            _ = try await validProvider.submit(
                LLMRequest(
                    modelID: "model",
                    prompt: "",
                    timeout: .seconds(5)
                )
            )
        }
        await expectProviderError(.invalidRequest) {
            _ = try await validProvider.submit(
                LLMRequest(
                    modelID: "model",
                    prompt: "Prompt",
                    timeout: .zero
                )
            )
        }
    }

    private func makeProvider(
        sendRequest: @escaping LLMServerProvider.RequestSender
    ) -> LLMServerProvider {
        LLMServerProvider(
            configuration: LLMServerConfiguration(
                providerID: "test-server",
                baseURL: URL(string: "http://127.0.0.1:8080")!,
                completionPath: "/v1/chat/completions"
            ),
            sendRequest: sendRequest
        )
    }

    private func makeRequest() -> LLMRequest {
        LLMRequest(
            modelID: "test-model",
            prompt: "Prompt",
            timeout: .seconds(5)
        )
    }

    private func expectProviderError(
        _ expectedError: LLMServerProviderError,
        operation: () async throws -> Void,
        sourceLocation: SourceLocation = #_sourceLocation
    ) async {
        do {
            try await operation()
            Issue.record(
                "Expected provider to fail with \(expectedError).",
                sourceLocation: sourceLocation
            )
        } catch let error as LLMServerProviderError {
            #expect(error == expectedError, sourceLocation: sourceLocation)
        } catch {
            Issue.record(
                "Unexpected error: \(error)",
                sourceLocation: sourceLocation
            )
        }
    }
}

private actor HTTPRequestRecorder {
    private var requests: [URLRequest] = []

    var lastRequest: URLRequest? {
        requests.last
    }

    func record(_ request: URLRequest) {
        requests.append(request)
    }
}

private func makeHTTPResponse(
    for request: URLRequest,
    statusCode: Int
) -> HTTPURLResponse {
    HTTPURLResponse(
        url: request.url!,
        statusCode: statusCode,
        httpVersion: "HTTP/1.1",
        headerFields: ["Content-Type": "application/json"]
    )!
}

private func requestBody(
    from request: URLRequest
) throws -> [String: Any] {
    let data = try #require(request.httpBody)
    return try #require(
        JSONSerialization.jsonObject(with: data) as? [String: Any]
    )
}
