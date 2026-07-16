public struct Evidence: Codable, Equatable, Sendable {
    public let metric: String
    public let observedValue: Int
    public let thresholdValue: Int

    public init(
        metric: String,
        observedValue: Int,
        thresholdValue: Int
    ) {
        self.metric = metric
        self.observedValue = observedValue
        self.thresholdValue = thresholdValue
    }
}
