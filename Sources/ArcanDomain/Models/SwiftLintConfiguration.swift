public struct SwiftLintConfiguration: Codable, Equatable, Sendable {
    public let availability: AnalyzerAvailabilityPolicy

    public init(
        availability: AnalyzerAvailabilityPolicy = .optional
    ) {
        self.availability = availability
    }
}
