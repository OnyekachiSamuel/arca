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

  @Test("loads the LLM provider and experiment parameters")
  func loadsLLMConfiguration() throws {
    try withTemporaryDirectory { directory in
      try write(
        """
        {
          "schemaVersion": 1,
          "llm": {
            "providerID": "local-qwen",
            "baseURL": "http://127.0.0.1:1234",
            "completionPath": "/v1/chat/completions",
            "modelID": "qwen2.5-coder",
            "timeoutSeconds": 120,
            "temperature": 0.2,
            "seed": 42
          }
        }
        """, to: directory)

      let llm = try #require(
        ConfigurationLoader().load(from: directory).llm
      )
      #expect(llm.providerID == "local-qwen")
      #expect(llm.baseURL == "http://127.0.0.1:1234")
      #expect(llm.modelID == "qwen2.5-coder")
      #expect(llm.timeoutSeconds == 120)
      #expect(llm.temperature == 0.2)
      #expect(llm.seed == 42)
    }
  }

  @Test("static-analysis configuration is rejected")
  func rejectsRemovedConfiguration() throws {
    for field in ["godObject", "swiftLint"] {
      try withTemporaryDirectory { directory in
        try write(
          "{\"schemaVersion\":1,\"\(field)\":{}}",
          to: directory
        )
        #expect(
          throws: ConfigurationLoadingError.unknownField(field)
        ) {
          try ConfigurationLoader().load(from: directory)
        }
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
      try write("{}", to: directory)
      #expect(throws: ConfigurationLoadingError.missingSchemaVersion) {
        try ConfigurationLoader().load(from: directory)
      }
      try write("{\"schemaVersion\":2}", to: directory)
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
