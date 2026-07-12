public struct GodObjectThresholds: Codable, Equatable, Sendable {
    public let maximumLines: Int
    public let maximumMethods: Int
    public let maximumStoredProperties: Int
    public let minimumTriggeredSignals: Int

    public init(
        maximumLines: Int = 500,
        maximumMethods: Int = 25,
        maximumStoredProperties: Int = 20,
        minimumTriggeredSignals: Int = 2
    ) {
        self.maximumLines = maximumLines
        self.maximumMethods = maximumMethods
        self.maximumStoredProperties = maximumStoredProperties
        self.minimumTriggeredSignals = minimumTriggeredSignals
    }
}
