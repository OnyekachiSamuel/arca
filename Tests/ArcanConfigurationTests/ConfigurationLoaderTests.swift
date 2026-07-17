import ArcanConfiguration
import ArcanDomain
import Foundation
import Testing

@Suite("Configuration loader")
struct ConfigurationLoaderTests {
    @Test("missing configuration file uses defaults")
    func missingFileUsesDefaults() throws {
        try withTemporaryDirectory { directory in
            let configuration = try ConfigurationLoader().load(from: directory)

            #expect(configuration == .defaults)
        }
    }

    @Test("schema-only configuration uses default rule thresholds")
    func schemaOnlyUsesDefaults() throws {
        try withTemporaryDirectory { directory in
            try writeConfiguration(
                """
                {
                  "schemaVersion": 1
                }
                """,
                to: directory
            )

            let configuration = try ConfigurationLoader().load(from: directory)

            #expect(configuration.schemaVersion == 1)
            #expect(
                configuration.godObjectThresholds == GodObjectThresholds()
            )
        }
    }

    @Test("partial rule configuration merges with defaults")
    func partialConfigurationMergesWithDefaults() throws {
        try withTemporaryDirectory { directory in
            try writeConfiguration(
                """
                {
                  "schemaVersion": 1,
                  "godObject": {
                    "maximumLines": 120,
                    "minimumTriggeredSignals": 3
                  }
                }
                """,
                to: directory
            )

            let configuration = try ConfigurationLoader().load(from: directory)

            #expect(configuration.godObjectThresholds == GodObjectThresholds(
                maximumLines: 120,
                maximumMethods: 25,
                maximumStoredProperties: 20,
                minimumTriggeredSignals: 3
            ))
        }
    }

    @Test("all God Object thresholds can be configured")
    func completeConfigurationIsLoaded() throws {
        try withTemporaryDirectory { directory in
            try writeConfiguration(
                """
                {
                  "schemaVersion": 1,
                  "godObject": {
                    "maximumLines": 300,
                    "maximumMethods": 15,
                    "maximumStoredProperties": 12,
                    "minimumTriggeredSignals": 1
                  }
                }
                """,
                to: directory
            )

            let configuration = try ConfigurationLoader().load(from: directory)

            #expect(configuration.godObjectThresholds == GodObjectThresholds(
                maximumLines: 300,
                maximumMethods: 15,
                maximumStoredProperties: 12,
                minimumTriggeredSignals: 1
            ))
        }
    }

    @Test("malformed JSON produces a diagnostic")
    func malformedJSONIsRejected() throws {
        try withTemporaryDirectory { directory in
            let file = try writeConfiguration(
                "{ \"schemaVersion\": 1,",
                to: directory
            )

            #expect(throws: ConfigurationLoadingError.invalidJSON(file.path)) {
                try ConfigurationLoader().load(from: directory)
            }
        }
    }

    @Test("schema version is required")
    func missingSchemaVersionIsRejected() throws {
        try withTemporaryDirectory { directory in
            try writeConfiguration(
                """
                {
                  "godObject": {
                    "maximumLines": 120
                  }
                }
                """,
                to: directory
            )

            #expect(
                throws: ConfigurationLoadingError.missingSchemaVersion
            ) {
                try ConfigurationLoader().load(from: directory)
            }
        }
    }

    @Test("unknown schema version produces a diagnostic")
    func unknownSchemaVersionIsRejected() throws {
        try withTemporaryDirectory { directory in
            try writeConfiguration(
                """
                {
                  "schemaVersion": 2
                }
                """,
                to: directory
            )

            #expect(
                throws: ConfigurationLoadingError.unsupportedSchemaVersion(2)
            ) {
                try ConfigurationLoader().load(from: directory)
            }
        }
    }

    @Test("unknown fields produce a diagnostic")
    func unknownFieldIsRejected() throws {
        try withTemporaryDirectory { directory in
            try writeConfiguration(
                """
                {
                  "schemaVersion": 1,
                  "godObject": {
                    "maximumLinez": 120
                  }
                }
                """,
                to: directory
            )

            #expect(
                throws: ConfigurationLoadingError.unknownField(
                    "godObject.maximumLinez"
                )
            ) {
                try ConfigurationLoader().load(from: directory)
            }
        }
    }

    @Test("wrong field types produce a diagnostic")
    func wrongFieldTypeIsRejected() throws {
        try withTemporaryDirectory { directory in
            try writeConfiguration(
                """
                {
                  "schemaVersion": 1,
                  "godObject": {
                    "maximumLines": "many"
                  }
                }
                """,
                to: directory
            )

            #expect(throws: ConfigurationLoadingError.invalidValue(
                field: "godObject.maximumLines",
                reason: "expected an integer."
            )) {
                try ConfigurationLoader().load(from: directory)
            }
        }
    }

    @Test("out-of-range values produce a diagnostic")
    func invalidThresholdIsRejected() throws {
        try withTemporaryDirectory { directory in
            try writeConfiguration(
                """
                {
                  "schemaVersion": 1,
                  "godObject": {
                    "minimumTriggeredSignals": 4
                  }
                }
                """,
                to: directory
            )

            #expect(throws: ConfigurationLoadingError.invalidValue(
                field: "godObject.minimumTriggeredSignals",
                reason: "must be between 1 and 3."
            )) {
                try ConfigurationLoader().load(from: directory)
            }
        }
    }

    @discardableResult
    private func writeConfiguration(
        _ content: String,
        to directory: URL
    ) throws -> URL {
        let file = directory.appendingPathComponent(".arcan.json")
        try content.write(to: file, atomically: true, encoding: .utf8)
        return file
    }

    private func withTemporaryDirectory<Result>(
        _ body: (URL) throws -> Result
    ) throws -> Result {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: directory) }
        return try body(directory)
    }
}
