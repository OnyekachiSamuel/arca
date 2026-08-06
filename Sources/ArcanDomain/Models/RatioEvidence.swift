public struct RatioEvidence: Codable, Equatable, Sendable {
    public let metricName: String
    public let observedValue: Double
    public let thresholdValue: Double

    public init(
        metricName: String,
        observedValue: Double,
        thresholdValue: Double
    ) {
        self.metricName = metricName
        self.observedValue = observedValue
        self.thresholdValue = thresholdValue
    }
}
