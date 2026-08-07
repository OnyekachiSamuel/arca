import ArcaAnalysis
import ArcaDomain
import Foundation

public struct GodObjectAnalyzer: Analyzer {
    public let id = "god-object"
    public let supportedReviewTypes: Set<ReviewType> = [.godObject]

    private let thresholds: GodObjectThresholds
    private let structureProvider: any SwiftStructureProvider
    private let ruleMetadata: GodObjectRuleMetadata

    public init(
        thresholds: GodObjectThresholds = GodObjectThresholds(),
        structureProvider: any SwiftStructureProvider,
        ruleMetadata: GodObjectRuleMetadata = .standard
    ) {
        self.thresholds = thresholds
        self.structureProvider = structureProvider
        self.ruleMetadata = ruleMetadata
    }

    public func analyze(context: AnalysisContext) async throws -> AnalyzerResult {
        var candidates: [FindingCandidate] = []

        let extractedMetrics = try structureProvider.extractMetrics(
            from: context.sourceFiles
        )
        for metrics in extractedMetrics {
            let structuralEvidence = triggeredStructuralEvidence(for: metrics)
            guard structuralEvidence.count
                    >= thresholds.minimumTriggeredSignals,
                  let cohesion = metrics.tightClassCohesion,
                  cohesion < thresholds.minimumTightClassCohesion else {
                continue
            }
            let evidence = structuralEvidence + [
                .ratio(RatioEvidence(
                    metricName: "tightClassCohesion",
                    observedValue: cohesion,
                    thresholdValue: thresholds.minimumTightClassCohesion
                ))
            ]
            candidates.append(try GodObjectCandidateMapper(
                ruleMetadata: ruleMetadata,
                analyzerID: id
            ).map(metrics: metrics, evidence: evidence))
        }

        return AnalyzerResult(analyzerID: id, candidates: candidates)
    }

    private func triggeredStructuralEvidence(
        for metrics: TypeStructuralMetrics
    ) -> [FindingEvidence] {
        var evidence: [FindingEvidence] = []

        if metrics.lineCount > thresholds.maximumLines {
            evidence.append(.metric(MetricEvidence(
                metricName: "lines",
                observedValue: metrics.lineCount,
                thresholdValue: thresholds.maximumLines
            )))
        }
        if metrics.methodCount > thresholds.maximumMethods {
            evidence.append(.metric(MetricEvidence(
                metricName: "methods",
                observedValue: metrics.methodCount,
                thresholdValue: thresholds.maximumMethods
            )))
        }
        if metrics.propertyCount > thresholds.maximumStoredProperties {
            evidence.append(.metric(MetricEvidence(
                metricName: "storedProperties",
                observedValue: metrics.propertyCount,
                thresholdValue: thresholds.maximumStoredProperties
            )))
        }

        return evidence
    }
}
