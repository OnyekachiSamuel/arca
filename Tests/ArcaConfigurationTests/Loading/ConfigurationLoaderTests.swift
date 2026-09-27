import ArcaConfiguration
import ArcaDomain
import Foundation
import Testing

@Suite("LLM-only configuration loader")
struct ConfigurationLoaderTests {
  @Test("missing file uses schema-one defaults")
  func missingFileUsesDefaults() throws {
    try withTemporaryDirectory { directory in
      let configuration = try ConfigurationLoader().load(from: directory)
      #expect(configuration == .defaults)
      #expect(configuration.llm == nil)
    }
  }

  @Test("loads named LLM providers and the default provider")
  func loadsLLMConfiguration() throws {
    try withTemporaryDirectory { directory in
      _ = try write(
        """
        {
          "schemaVersion": 1,
          "llm": {
            "defaultProvider": "local",
            "providers": [
              {
                "id": "local",
                "baseURL": "http://127.0.0.1:1234",
                "completionPath": "/v1/chat/completions",
                "modelID": "qwen2.5-coder",
                "timeoutSeconds": 120,
                "temperature": 0.2,
                "seed": 42
              },
              {
                "id": "openai",
                "baseURL": "https://api.openai.com",
                "completionPath": "/v1/chat/completions",
                "modelID": "gpt-test",
                "apiKeyEnvironmentVariable": "OPENAI_API_KEY",
                "timeoutSeconds": 90
              }
            ]
          }
        }
        """, to: directory)

      let llm = try #require(
        ConfigurationLoader().load(from: directory).llm
      )
      #expect(llm.defaultProvider == "local")
      #expect(llm.providers.count == 2)
      let local = try #require(llm.provider(id: "local"))
      #expect(local.baseURL == "http://127.0.0.1:1234")
      #expect(local.modelID == "qwen2.5-coder")
      #expect(local.timeoutSeconds == 120)
      #expect(local.temperature == 0.2)
      #expect(local.seed == 42)
      let openAI = try #require(llm.provider(id: "openai"))
      #expect(openAI.apiKeyEnvironmentVariable == "OPENAI_API_KEY")
      #expect(openAI.timeoutSeconds == 90)
    }
  }

  @Test("default provider must identify one configured provider")
  func validatesDefaultProvider() throws {
    try withTemporaryDirectory { directory in
      _ = try write(
        """
        {
          "schemaVersion": 1,
          "llm": {
            "defaultProvider": "missing",
            "providers": [{
              "id": "local",
              "baseURL": "http://127.0.0.1:1234",
              "modelID": "local-model"
            }]
          }
        }
        """, to: directory)

      #expect(
        throws: ConfigurationLoadingError.invalidValue(
          field: "llm.defaultProvider",
          reason: "must identify a configured provider."
        )
      ) {
        try ConfigurationLoader().load(from: directory)
      }
    }
  }

  @Test("unknown configuration fields are rejected")
  func rejectsUnknownConfigurationField() throws {
    try withTemporaryDirectory { directory in
      _ = try write(
        "{\"schemaVersion\":1,\"unexpected\":{}}",
        to: directory
      )
      #expect(
        throws: ConfigurationLoadingError.unknownField("unexpected")
      ) {
        try ConfigurationLoader().load(from: directory)
      }
    }
  }

  @Test("malformed JSON is rejected")
  func rejectsMalformedJSON() throws {
    try withTemporaryDirectory { directory in
      let file = try write("{\"schemaVersion\":1,", to: directory)
      #expect(throws: ConfigurationLoadingError.invalidJSON(file.path)) {
        try ConfigurationLoader().load(from: directory)
      }
    }
  }

  @Test("schema version is required and fixed at one")
  func validatesSchemaVersion() throws {
    try withTemporaryDirectory { directory in
      _ = try write("{}", to: directory)
      #expect(throws: ConfigurationLoadingError.missingSchemaVersion) {
        try ConfigurationLoader().load(from: directory)
      }
      _ = try write("{\"schemaVersion\":2}", to: directory)
      #expect(
        throws: ConfigurationLoadingError.unsupportedSchemaVersion(2)
      ) {
        try ConfigurationLoader().load(from: directory)
      }
    }
  }

  private func write(_ value: String, to directory: URL) throws -> URL {
    let file = directory.appendingPathComponent(".arca.json")
    try value.write(to: file, atomically: true, encoding: .utf8)
    return file
  }

  private func withTemporaryDirectory(
    _ body: (URL) throws -> Void
  ) throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(
      at: directory,
      withIntermediateDirectories: true
    )
    defer { try? FileManager.default.removeItem(at: directory) }
    try body(directory)
  }
}
