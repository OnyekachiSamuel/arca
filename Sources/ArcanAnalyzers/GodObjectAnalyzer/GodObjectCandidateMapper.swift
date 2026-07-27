import ArcanDomain
import Foundation

struct GodObjectCandidateMapper: Sendable {
    let ruleMetadata: GodObjectRuleMetadata
    let analyzerID: String

    func map(
        metrics: TypeStructuralMetrics,
        sourceFile: SourceFile,
        evidence: [Evidence]
    ) throws -> FindingCandidate {
        try FindingCandidate(
            candidateID: UUID(),
            ruleID: ruleMetadata.ruleID,
            title: ruleMetadata.title,
            explanation: "Type '\(metrics.name)' \(ruleMetadata.explanation)",
            filePath: sourceFile.path,
            range: metrics.range,
            proposedSeverity: ruleMetadata.severity,
            proposedCategory: ruleMetadata.category,
            evidence: evidence.map {
                .metric(MetricEvidence(
                    metricName: $0.metric,
                    observedValue: $0.observedValue,
                    thresholdValue: $0.thresholdValue
                ))
            },
            sourceIdentifiers: [analyzerID],
            analyzerMetadata: [
                "typeName": .string(metrics.name),
                "typeKind": .string(metrics.kind.rawValue),
                "lineCount": .integer(metrics.lineCount),
                "methodCount": .integer(metrics.methodCount),
                "propertyCount": .integer(metrics.propertyCount),
                "sourcePath": .string(sourceFile.path)
            ]
        )
    }
}
