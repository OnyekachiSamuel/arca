import ArcaAnalysis
import ArcaDomain
import ArcaProcess
import Foundation

public struct SwiftLintAnalyzer: Analyzer {
    public let id = "swiftlint"
    public let supportedReviewTypes: Set<ReviewType> = [
        .style,
        .teamConvention
    ]

    private let executableURL: URL
    private let workingDirectoryURL: URL
    private let timeout: Duration
    private let availabilityPolicy: AnalyzerAvailabilityPolicy
    private let configurationPath: String?
    private let processRunner: any ProcessRunning

    public init(
        executableURL: URL,
        workingDirectoryURL: URL,
        timeout: Duration = .seconds(30),
        availabilityPolicy: AnalyzerAvailabilityPolicy = .required,
        configurationPath: String? = nil,
        processRunner: any ProcessRunning
    ) {
        self.executableURL = executableURL
        self.workingDirectoryURL = workingDirectoryURL
        self.timeout = timeout
        self.availabilityPolicy = availabilityPolicy
        self.configurationPath = configurationPath
        self.processRunner = processRunner
    }

    public func analyze(
        context: AnalysisContext
    ) async throws -> AnalyzerResult {
        let paths = Array(Set(context.sourceFiles.map(\.path))).sorted()
        guard !paths.isEmpty else {
            return AnalyzerResult(
                analyzerID: id,
                candidates: [],
                tool: ToolMetadata(name: "SwiftLint")
            )
        }

        let version = await loadVersion()
        let result: ProcessResult
        do {
            result = try await processRunner.run(ProcessRequest(
                executableURL: executableURL,
                arguments: lintArguments(paths: paths),
                workingDirectoryURL: workingDirectoryURL,
                timeout: timeout
            ))
        } catch let error as ProcessExecutionError {
            guard let reason = unavailableReason(from: error) else {
                throw error
            }
            return try await UnavailableSwiftLintAnalyzer(
                reason: reason,
                policy: availabilityPolicy
            ).analyze(context: context)
        }

        let violations = try decodeViolations(from: result)
        let candidateMapper = SwiftLintCandidateMapper(
            workingDirectoryURL: workingDirectoryURL,
            analyzerID: id
        )
        let candidates = try violations
            .map(candidateMapper.map)
            .filter {
                context.request.selectedReviewTypes.contains(
                    $0.proposedCategory == .teamConvention
                        ? .teamConvention
                        : .style
                )
            }
            .sorted(by: candidatesAreInStableOrder)

        return AnalyzerResult(
            analyzerID: id,
            candidates: candidates,
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
        var arguments = [
            "lint",
            "--reporter", "json",
            "--quiet",
            "--force-exclude"
        ]
        if let configurationPath {
            arguments += ["--config", configurationPath]
        }
        return arguments + paths
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

    private func candidatesAreInStableOrder(
        _ left: FindingCandidate,
        _ right: FindingCandidate
    ) -> Bool {
        let leftLocation = (
            left.filePath,
            left.range?.startLine ?? 0,
            left.range?.startColumn ?? 0,
            left.ruleID ?? ""
        )
        let rightLocation = (
            right.filePath,
            right.range?.startLine ?? 0,
            right.range?.startColumn ?? 0,
            right.ruleID ?? ""
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

    private func unavailableReason(
        from error: ProcessExecutionError
    ) -> SwiftLintUnavailableReason? {
        switch error {
        case .executableNotFound(let path):
            .configuredExecutableNotFound(path)
        case .executableNotRunnable(let path):
            .configuredExecutableNotRunnable(path)
        case .couldNotStart(let path, let reason):
            .executableCouldNotStart(path: path, reason: reason)
        case .executableURLMustBeAbsolute,
             .executableNotApproved,
             .invalidTimeout,
             .invalidWorkingDirectory:
            nil
        }
    }
}
