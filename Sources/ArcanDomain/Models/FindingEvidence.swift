public enum FindingEvidence: Codable, Equatable, Sendable {
    case metric(MetricEvidence)
    case analyzer(AnalyzerEvidence)
    case sourceCode(SourceCodeEvidence)

    private enum Kind: String, Codable {
        case metric
        case analyzer
        case sourceCode
    }

    private enum CodingKeys: String, CodingKey {
        case kind
        case metricName
        case observedValue
        case thresholdValue
        case description
        case range
        case excerpt
        case externalRuleID
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        switch try container.decode(Kind.self, forKey: .kind) {
        case .metric:
            self = .metric(
                MetricEvidence(
                    metricName: try container.decode(
                        String.self,
                        forKey: .metricName
                    ),
                    observedValue: try container.decode(
                        Int.self,
                        forKey: .observedValue
                    ),
                    thresholdValue: try container.decode(
                        Int.self,
                        forKey: .thresholdValue
                    )
                )
            )
        case .analyzer:
            self = .analyzer(
                AnalyzerEvidence(
                    description: try container.decode(
                        String.self,
                        forKey: .description
                    ),
                    externalRuleID: try container.decodeIfPresent(
                        String.self,
                        forKey: .externalRuleID
                    ),
                    range: try container.decodeIfPresent(
                        SourceRange.self,
                        forKey: .range
                    )
                )
            )
        case .sourceCode:
            self = .sourceCode(
                SourceCodeEvidence(
                    description: try container.decode(
                        String.self,
                        forKey: .description
                    ),
                    range: try container.decode(
                        SourceRange.self,
                        forKey: .range
                    ),
                    excerpt: try container.decode(
                        String.self,
                        forKey: .excerpt
                    )
                )
            )
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .metric(let evidence):
            try container.encode(Kind.metric, forKey: .kind)
            try container.encode(
                evidence.metricName,
                forKey: .metricName
            )
            try container.encode(
                evidence.observedValue,
                forKey: .observedValue
            )
            try container.encode(
                evidence.thresholdValue,
                forKey: .thresholdValue
            )
        case .analyzer(let evidence):
            try container.encode(Kind.analyzer, forKey: .kind)
            try container.encode(evidence.description, forKey: .description)
            try container.encodeIfPresent(
                evidence.externalRuleID,
                forKey: .externalRuleID
            )
            try container.encodeIfPresent(evidence.range, forKey: .range)
        case .sourceCode(let evidence):
            try container.encode(Kind.sourceCode, forKey: .kind)
            try container.encode(
                evidence.description,
                forKey: .description
            )
            try container.encode(evidence.range, forKey: .range)
            try container.encode(evidence.excerpt, forKey: .excerpt)
        }
    }
}
