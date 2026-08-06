public struct TightClassCohesionResult: Equatable, Sendable {
    public let value: Double?
    public let eligibleMethodCount: Int
    public let connectedPairCount: Int
    public let possiblePairCount: Int

    public init(
        value: Double?,
        eligibleMethodCount: Int,
        connectedPairCount: Int,
        possiblePairCount: Int
    ) {
        self.value = value
        self.eligibleMethodCount = eligibleMethodCount
        self.connectedPairCount = connectedPairCount
        self.possiblePairCount = possiblePairCount
    }
}

public struct TightClassCohesionCalculator: Sendable {
    public init() {}

    public func calculate(
        methods: [MethodPropertyAccess],
        storedProperties: Set<String>
    ) -> TightClassCohesionResult {
        let methodCount = methods.count
        let possiblePairCount = methodCount * (methodCount - 1) / 2
        guard methodCount >= 2,
              !storedProperties.isEmpty,
              possiblePairCount > 0 else {
            return TightClassCohesionResult(
                value: nil,
                eligibleMethodCount: methodCount,
                connectedPairCount: 0,
                possiblePairCount: possiblePairCount
            )
        }

        var connectedPairCount = 0
        for leftIndex in methods.indices {
            for rightIndex in methods.indices where rightIndex > leftIndex {
                if !methods[leftIndex].accessedStoredProperties
                    .intersection(methods[rightIndex].accessedStoredProperties)
                    .isEmpty {
                    connectedPairCount += 1
                }
            }
        }

        return TightClassCohesionResult(
            value: Double(connectedPairCount) / Double(possiblePairCount),
            eligibleMethodCount: methodCount,
            connectedPairCount: connectedPairCount,
            possiblePairCount: possiblePairCount
        )
    }
}
