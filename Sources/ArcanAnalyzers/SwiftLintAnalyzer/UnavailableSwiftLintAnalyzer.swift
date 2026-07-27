import ArcanAnalysis
import ArcanDomain

public struct UnavailableSwiftLintAnalyzer: Analyzer {
    public let id = "swiftlint"
    public let supportedReviewTypes: Set<ReviewType> = [.style]

    private let reason: SwiftLintUnavailableReason
    private let policy: AnalyzerAvailabilityPolicy

    public init(
        reason: SwiftLintUnavailableReason,
        policy: AnalyzerAvailabilityPolicy
    ) {
        self.reason = reason
        self.policy = policy
    }

    public func analyze(
        context: AnalysisContext
    ) async throws -> AnalyzerResult {
        switch policy {
        case .optional:
            AnalyzerResult(
                analyzerID: id,
                candidates: [],
                tool: ToolMetadata(name: "SwiftLint"),
                executionStatus: .skipped,
                diagnostics: [
                    AnalyzerDiagnostic(
                        code: "ARCAN-SWIFTLINT-UNAVAILABLE",
                        severity: .warning,
                        message: "\(reason.description) Style analysis was "
                            + "skipped. Install SwiftLint or set "
                            + "ARCAN_SWIFTLINT_EXECUTABLE."
                    )
                ]
            )
        case .required:
            throw SwiftLintAvailabilityError.requiredToolUnavailable(reason)
        }
    }
}
