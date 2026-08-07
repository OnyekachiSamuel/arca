import ArcaDomain

public struct CategorizedReviewReportBuilder: Sendable {
    public init() {}

    public func build(
        from result: ReviewCategorizationResult
    ) -> CategorizedReviewReport {
        let decisions = result.categorization?.decisions ?? []
        let candidatesByID = Dictionary(
            uniqueKeysWithValues: result.analysis.candidates.map {
                ($0.candidateID, $0)
            }
        )
        var confirmedFindings: [Finding] = []
        var uncertainFindings: [Finding] = []
        var buildingDiagnostics: [AnalyzerDiagnostic] = []

        for decision in decisions where decision.assessment != .rejected {
            let candidates = decision.candidateIDs.compactMap {
                candidatesByID[$0]
            }
            guard candidates.count == decision.candidateIDs.count,
                  let findingID = decision.candidateIDs.first else {
                buildingDiagnostics.append(AnalyzerDiagnostic(
                    code: "ARCA-REPORT-MISSING-CANDIDATE",
                    severity: .warning,
                    message: "A categorized finding references a candidate that is unavailable."
                ))
                continue
            }

            let finding = Finding(
                id: findingID,
                candidateIDs: decision.candidateIDs,
                assessment: decision.assessment,
                ruleID: decision.canonicalRuleID,
                title: decision.title,
                category: decision.category,
                severity: decision.severity,
                classificationRationale: decision.rationale,
                sources: decision.sourceIdentifiers,
                candidates: candidates
            )

            switch decision.assessment {
            case .confirmed:
                confirmedFindings.append(finding)
            case .uncertain:
                uncertainFindings.append(finding)
            case .rejected:
                break
            }
        }

        return CategorizedReviewReport(
            schemaVersion: CategorizedReviewReport.currentSchemaVersion,
            requestID: result.analysis.requestID,
            categorizationSummary: result.categorization?.summary,
            confirmedFindings: confirmedFindings,
            uncertainFindings: uncertainFindings,
            candidates: result.analysis.candidates,
            categorizationDecisions: decisions,
            counts: counts(
                candidates: result.analysis.candidates,
                decisions: decisions,
                visibleFindings: confirmedFindings + uncertainFindings
            ),
            diagnostics: result.analysis.diagnostics
                + result.categorizationDiagnostics
                + buildingDiagnostics,
            analyzerResults: result.analysis.analyzerResults,
            categorizationExecutionMetadata: result.llmExecutionMetadata
        )
    }

    private func counts(
        candidates: [FindingCandidate],
        decisions: [FindingCategorizationDecision],
        visibleFindings: [Finding]
    ) -> ReviewReportCounts {
        ReviewReportCounts(
            totalCandidates: candidates.count,
            confirmed: candidateCount(for: .confirmed, in: decisions),
            rejected: candidateCount(for: .rejected, in: decisions),
            uncertain: candidateCount(for: .uncertain, in: decisions),
            findingsPerCategory: FindingCategory.allCases.compactMap {
                category in
                let count = visibleFindings.filter {
                    $0.category == category
                }.count
                return count == 0
                    ? nil
                    : CategoryFindingCount(category: category, count: count)
            }
        )
    }

    private func candidateCount(
        for assessment: FindingAssessment,
        in decisions: [FindingCategorizationDecision]
    ) -> Int {
        decisions.filter { $0.assessment == assessment }
            .reduce(0) { $0 + $1.candidateIDs.count }
    }
}
