import ArcanAnalysis
import ArcanDomain
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
        var findings: [Finding] = []

        for sourceFile in context.sourceFiles {
            let extractedMetrics = try structureProvider.extractMetrics(from: sourceFile)
            findings.append(contentsOf: extractedMetrics.compactMap { metrics in
                let evidence = triggeredEvidence(for: metrics)
                guard evidence.count >= thresholds.minimumTriggeredSignals else {
                    return nil
                }
                return makeFinding(
                    for: metrics,
                    in: sourceFile,
                    evidence: evidence
                )
            })
        }

        return AnalyzerResult(analyzerID: id, findings: findings)
    }

    private func triggeredEvidence(
        for metrics: TypeStructuralMetrics
    ) -> [Evidence] {
        var evidence: [Evidence] = []

        if metrics.lineCount > thresholds.maximumLines {
            evidence.append(Evidence(
                metric: "lines",
                observedValue: metrics.lineCount,
                thresholdValue: thresholds.maximumLines
            ))
        }
        if metrics.methodCount > thresholds.maximumMethods {
            evidence.append(Evidence(
                metric: "methods",
                observedValue: metrics.methodCount,
                thresholdValue: thresholds.maximumMethods
            ))
        }
        if metrics.propertyCount > thresholds.maximumStoredProperties {
            evidence.append(Evidence(
                metric: "storedProperties",
                observedValue: metrics.propertyCount,
                thresholdValue: thresholds.maximumStoredProperties
            ))
        }

        return evidence
    }

    private func makeFinding(
        for metrics: TypeStructuralMetrics,
        in sourceFile: SourceFile,
        evidence: [Evidence]
    ) -> Finding {
        Finding(
            id: UUID(),
            ruleID: ruleMetadata.ruleID,
            title: ruleMetadata.title,
            severity: ruleMetadata.severity,
            filePath: sourceFile.path,
            range: metrics.range,
            explanation: "Type '\(metrics.name)' \(ruleMetadata.explanation)",
            evidence: evidence,
            suggestion: ruleMetadata.suggestion
        )
    }
}
