enum ConfigurationDecodingIssue: Error {
    case missingSchemaVersion
    case unknownField(String)
    case invalidValue(field: String, reason: String)

    var loadingError: ConfigurationLoadingError {
        switch self {
        case .missingSchemaVersion:
            .missingSchemaVersion
        case .unknownField(let field):
            .unknownField(field)
        case .invalidValue(let field, let reason):
            .invalidValue(field: field, reason: reason)
        }
    }
}
