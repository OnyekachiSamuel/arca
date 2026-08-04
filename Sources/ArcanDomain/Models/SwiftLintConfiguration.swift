public struct SwiftLintConfiguration: Codable, Equatable, Sendable {
    public let availability: AnalyzerAvailabilityPolicy
    public let configurationPath: String?

    public init(
        availability: AnalyzerAvailabilityPolicy = .optional,
        configurationPath: String? = nil
    ) {
        self.availability = availability
        self.configurationPath = configurationPath
    }
}
