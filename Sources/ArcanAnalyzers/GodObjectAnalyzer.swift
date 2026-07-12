import ArcanAnalysis
import ArcanDomain
import Foundation

public struct GodObjectAnalyzer: Analyzer {
    public let id = "god-object"
    public let supportedReviewTypes: Set<ReviewType> = [.godObject]

    private let thresholds: GodObjectThresholds
    private let structureProvider: any SwiftStructureProvider

    public init(
        thresholds: GodObjectThresholds = GodObjectThresholds(),
        structureProvider: any SwiftStructureProvider
    ) {
        self.thresholds = thresholds
        self.structureProvider = structureProvider
    }

    public func analyze(context: AnalysisContext) async throws -> AnalyzerResult {
        var findings: [Finding] = []

        for sourceFile in context.sourceFiles {
            let metrics = try structureProvider.extractMetrics(from: sourceFile)
            findings.append(contentsOf: metrics.compactMap { metrics in
                guard isCandidate(metrics) else { return nil }
                return makeFinding(for: metrics, in: sourceFile)
            })
        }

        return AnalyzerResult(analyzerID: id, findings: findings)
    }

    private func isCandidate(_ metrics: TypeStructuralMetrics) -> Bool {
        var triggeredSignals = 0

        if metrics.lineCount > thresholds.maximumLines {
            triggeredSignals += 1
        }
        if metrics.methodCount > thresholds.maximumMethods {
            triggeredSignals += 1
        }
        if metrics.propertyCount > thresholds.maximumStoredProperties {
            triggeredSignals += 1
        }

        return triggeredSignals >= thresholds.minimumTriggeredSignals
    }

    private func makeFinding(
        for metrics: TypeStructuralMetrics,
        in sourceFile: SourceFile
    ) -> Finding {
        Finding(
            id: UUID(),
            ruleID: "ARCAN-GOD-001",
            title: "God Object candidate",
            severity: .warning,
            filePath: sourceFile.path,
            explanation: "Type '\(metrics.name)' exceeds the configured structural thresholds."
        )
    }
}
