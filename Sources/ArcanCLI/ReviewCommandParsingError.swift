import Foundation

enum ReviewCommandParsingError: Equatable, LocalizedError {
    case missingValue(option: String)
    case multipleSourceSelections
    case unsupportedReviewType(String)
    case unavailableReviewType(String, availableValues: [String])
    case unknownOption(String)
    case debugRequiresFile

    var errorDescription: String? {
        switch self {
        case .missingValue(let option):
            "Option '\(option)' requires a value."
        case .multipleSourceSelections:
            "Choose either --file or --changed, not both."
        case .unsupportedReviewType(let value):
            "Unsupported review type '\(value)'."
        case .unavailableReviewType(let value, let availableValues):
            """
            No analyzer is registered for review type '\(value)'. \
            Available values: \(availableValues.joined(separator: ", ")).
            """
        case .unknownOption(let option):
            "Unknown review option '\(option)'."
        case .debugRequiresFile:
            "Option '--debug' requires '--file'."
        }
    }
}
