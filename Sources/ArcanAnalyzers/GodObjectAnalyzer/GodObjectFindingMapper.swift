import ArcanDomain
import Foundation

struct GodObjectFindingMapper: Sendable {
    let ruleMetadata: GodObjectRuleMetadata

    func map(
        metrics: TypeStructuralMetrics,
        sourceFile: SourceFile,
        evidence: [Evidence]
    ) -> Finding {
        Finding(
            id: UUID(),
            ruleID: ruleMetadata.ruleID,
            title: ruleMetadata.title,
            category: ruleMetadata.category,
            severity: ruleMetadata.severity,
            filePath: sourceFile.path,
            range: metrics.range,
            explanation: "Type '\(metrics.name)' \(ruleMetadata.explanation)",
            evidence: evidence,
            suggestion: ruleMetadata.suggestion,
            metadata: [
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
