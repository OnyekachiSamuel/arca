public struct MetricEvidence: Codable, Equatable, Sendable {
    public let metricName: String
    public let observedValue: Int
    public let thresholdValue: Int

    public init(
        metricName: String,
        observedValue: Int,
        thresholdValue: Int
    ) {
        self.metricName = metricName
        self.observedValue = observedValue
        self.thresholdValue = thresholdValue
    }
}
