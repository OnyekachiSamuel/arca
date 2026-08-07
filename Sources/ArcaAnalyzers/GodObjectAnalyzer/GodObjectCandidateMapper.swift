import ArcaDomain
import Foundation

struct GodObjectCandidateMapper: Sendable {
    let ruleMetadata: GodObjectRuleMetadata
    let analyzerID: String

    func map(
        metrics: TypeStructuralMetrics,
        evidence: [FindingEvidence]
    ) throws -> FindingCandidate {
        try FindingCandidate(
            candidateID: UUID(),
            ruleID: ruleMetadata.ruleID,
            title: ruleMetadata.title,
            explanation: "Type '\(metrics.name)' \(ruleMetadata.explanation)",
            filePath: metrics.sourcePath,
            range: metrics.range,
            proposedSeverity: ruleMetadata.severity,
            proposedCategory: ruleMetadata.category,
            evidence: evidence,
            sourceIdentifiers: [analyzerID],
            analyzerMetadata: [
                "typeName": .string(metrics.name),
                "typeKind": .string(metrics.kind.rawValue),
                "lineCount": .integer(metrics.lineCount),
                "methodCount": .integer(metrics.methodCount),
                "propertyCount": .integer(metrics.propertyCount),
                "tightClassCohesion": metrics.tightClassCohesion.map {
                    .decimal($0)
                } ?? .string("unavailable"),
                "cohesionEligibleMethodCount": .integer(
                    metrics.cohesionEligibleMethodCount
                ),
                "cohesionConnectedPairCount": .integer(
                    metrics.cohesionConnectedPairCount
                ),
                "cohesionPossiblePairCount": .integer(
                    metrics.cohesionPossiblePairCount
                ),
                "sourcePath": .string(metrics.sourcePath)
            ]
        )
    }
}
