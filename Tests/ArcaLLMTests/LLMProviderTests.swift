import ArcaDomain
import ArcaLLM
import Testing

@Suite("LLM provider contract")
struct LLMProviderTests {
    @Test("mock provider returns text, usage metadata and duration")
    func submitsRequest() async throws {
        let request = LLMRequest(
            modelID: "mock-model",
            prompt: "Return a structured analysis response.",
            timeout: .seconds(10),
            seed: 42,
            temperature: 0.2
        )
        let expectedResponse = LLMResponse(
            text: #"{"summary":"Extract networking"}"#,
            usage: LLMTokenUsageMetadata(
                inputTokens: 120,
                outputTokens: 35,
                totalTokens: 155
            ),
            durationMilliseconds: 240
        )
        let mock = MockLLMProvider(response: expectedResponse)
        let provider: any LLMProvider = mock

        let response = try await provider.submit(request)

        #expect(provider.id == "mock")
        #expect(response == expectedResponse)
        #expect(await mock.recordedRequests == [request])
    }

    @Test("seed and temperature are optional")
    func optionalGenerationSettings() {
        let request = LLMRequest(
            modelID: "local-model",
            prompt: "Review this type.",
            timeout: .seconds(5)
        )

        #expect(request.seed == nil)
        #expect(request.temperature == nil)
    }

    @Test("usage metadata supports providers without token counts")
    func optionalUsageCounts() {
        let usage = LLMTokenUsageMetadata()
        let response = LLMResponse(
            text: "Local model response",
            usage: usage,
            durationMilliseconds: 80
        )

        #expect(response.usage.inputTokens == nil)
        #expect(response.usage.outputTokens == nil)
        #expect(response.usage.totalTokens == nil)
        #expect(response.durationMilliseconds == 80)
    }

    @Test("provider errors propagate to the caller")
    func propagatesProviderError() async {
        let provider: any LLMProvider = FailingLLMProvider()
        let request = LLMRequest(
            modelID: "unavailable-model",
            prompt: "Review this type.",
            timeout: .seconds(1)
        )

        do {
            _ = try await provider.submit(request)
            Issue.record("Expected the provider request to fail.")
        } catch let error as MockLLMProviderError {
            #expect(error == .unavailable)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}

private actor MockLLMProvider: LLMProvider {
    nonisolated let id = "mock"
    private let response: LLMResponse
    private(set) var recordedRequests: [LLMRequest] = []

    init(response: LLMResponse) {
        self.response = response
    }

    func submit(_ request: LLMRequest) async throws -> LLMResponse {
        recordedRequests.append(request)
        return response
    }
}

private struct FailingLLMProvider: LLMProvider {
    let id = "failing"

    func submit(_ request: LLMRequest) async throws -> LLMResponse {
        throw MockLLMProviderError.unavailable
    }
}

private enum MockLLMProviderError: Error, Equatable {
    case unavailable
}
