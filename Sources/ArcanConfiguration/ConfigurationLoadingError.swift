import Foundation

public enum ConfigurationLoadingError: Equatable, LocalizedError, Sendable {
    case unreadableFile(String)
    case invalidJSON(String)
    case missingSchemaVersion
    case unsupportedSchemaVersion(Int)
    case unknownField(String)
    case invalidValue(field: String, reason: String)

    public var errorDescription: String? {
        switch self {
        case .unreadableFile(let path):
            "Could not read configuration file: \(path)"
        case .invalidJSON(let path):
            "Invalid JSON in configuration file: \(path)"
        case .missingSchemaVersion:
            "Configuration field 'schemaVersion' is required."
        case .unsupportedSchemaVersion(let version):
            "Unsupported configuration schema version: \(version). Supported version: 1."
        case .unknownField(let field):
            "Unknown configuration field: \(field)"
        case .invalidValue(let field, let reason):
            "Invalid configuration value for '\(field)': \(reason)"
        }
    }
}
