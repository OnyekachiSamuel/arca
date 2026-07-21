import ArcanAnalysis
import ArcanDomain
import ArcanProcess
import Foundation

public struct SwiftLintAnalyzer: Analyzer {
    public let id = "swiftlint"
    public let supportedReviewTypes: Set<ReviewType> = [.style]

    private let executableURL: URL
    private let workingDirectoryURL: URL
    private let timeout: Duration
    private let processRunner: any ProcessRunning

    public init(
        executableURL: URL,
        workingDirectoryURL: URL,
        timeout: Duration = .seconds(30),
        processRunner: any ProcessRunning
    ) {
        self.executableURL = executableURL
        self.workingDirectoryURL = workingDirectoryURL
        self.timeout = timeout
        self.processRunner = processRunner
    }

    public func analyze(
        context: AnalysisContext
    ) async throws -> AnalyzerResult {
        let paths = Array(Set(context.sourceFiles.map(\.path))).sorted()
        guard !paths.isEmpty else {
            return AnalyzerResult(
                analyzerID: id,
                findings: [],
                tool: ToolMetadata(name: "SwiftLint")
            )
        }

        let version = await loadVersion()
        let result = try await processRunner.run(ProcessRequest(
            executableURL: executableURL,
            arguments: lintArguments(paths: paths),
            workingDirectoryURL: workingDirectoryURL,
            timeout: timeout
        ))

        let violations = try decodeViolations(from: result)
        let findings = try violations
            .map(makeFinding)
            .sorted(by: findingsAreInStableOrder)

        return AnalyzerResult(
            analyzerID: id,
            findings: findings,
            tool: ToolMetadata(name: "SwiftLint", version: version)
        )
    }

    private func loadVersion() async -> String? {
        guard let result = try? await processRunner.run(ProcessRequest(
            executableURL: executableURL,
            arguments: ["version"],
            workingDirectoryURL: workingDirectoryURL,
            timeout: timeout
        )), result.status == .exited(code: 0) else {
            return nil
        }

        let version = String(
            decoding: result.standardOutput,
            as: UTF8.self
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        return version.isEmpty ? nil : version
    }

    private func lintArguments(paths: [String]) -> [String] {
        [
            "lint",
            "--reporter", "json",
            "--quiet",
            "--force-exclude"
        ] + paths
    }

    private func decodeViolations(
        from result: ProcessResult
    ) throws -> [SwiftLintViolation] {
        switch result.status {
        case .timedOut:
            throw SwiftLintAnalyzerError.timedOut
        case .exited(let code):
            do {
                return try JSONDecoder().decode(
                    [SwiftLintViolation].self,
                    from: result.standardOutput
                )
            } catch {
                guard code == 0 else {
                    throw SwiftLintAnalyzerError.executionFailed(
                        status: code,
                        message: diagnosticMessage(from: result)
                    )
                }
                throw SwiftLintAnalyzerError.invalidJSON
            }
        }
    }

    private func makeFinding(
        _ violation: SwiftLintViolation
    ) throws -> Finding {
        Finding(
            id: UUID(),
            ruleID: "swiftlint.\(violation.ruleID)",
            externalRuleID: violation.ruleID,
            title: violation.type,
            severity: try severity(from: violation.severity),
            filePath: normalizedPath(violation.file),
            range: sourceRange(for: violation),
            explanation: violation.reason
        )
    }

    private func severity(from value: String) throws -> Severity {
        switch value.lowercased() {
        case "warning":
            .warning
        case "error":
            .error
        default:
            throw SwiftLintAnalyzerError.unsupportedSeverity(value)
        }
    }

    private func sourceRange(
        for violation: SwiftLintViolation
    ) -> SourceRange? {
        guard let line = violation.line, line > 0 else {
            return nil
        }
        let column = max(1, violation.character ?? 1)
        return SourceRange(
            startLine: line,
            startColumn: column,
            endLine: line,
            endColumn: column
        )
    }

    private func normalizedPath(_ path: String) -> String {
        let url: URL
        if path.hasPrefix("/") {
            url = URL(fileURLWithPath: path)
        } else {
            url = workingDirectoryURL.appendingPathComponent(path)
        }
        return url.standardizedFileURL.resolvingSymlinksInPath().path
    }

    private func findingsAreInStableOrder(
        _ left: Finding,
        _ right: Finding
    ) -> Bool {
        let leftLocation = (
            left.filePath,
            left.range?.startLine ?? 0,
            left.range?.startColumn ?? 0,
            left.externalRuleID ?? ""
        )
        let rightLocation = (
            right.filePath,
            right.range?.startLine ?? 0,
            right.range?.startColumn ?? 0,
            right.externalRuleID ?? ""
        )

        if leftLocation.0 != rightLocation.0 {
            return leftLocation.0 < rightLocation.0
        }
        if leftLocation.1 != rightLocation.1 {
            return leftLocation.1 < rightLocation.1
        }
        if leftLocation.2 != rightLocation.2 {
            return leftLocation.2 < rightLocation.2
        }
        return leftLocation.3 < rightLocation.3
    }

    private func diagnosticMessage(
        from result: ProcessResult
    ) -> String {
        let standardError = String(
            decoding: result.standardError,
            as: UTF8.self
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        return standardError.isEmpty
            ? "No valid JSON diagnostics were produced."
            : standardError
    }
}
