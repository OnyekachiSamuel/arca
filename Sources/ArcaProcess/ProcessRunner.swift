import Darwin
import Foundation

public struct ProcessRunner: ProcessRunning, Sendable {
    private let approvedExecutablePaths: Set<String>

    public init(approvedExecutableURLs: Set<URL>) {
        approvedExecutablePaths = Set(
            approvedExecutableURLs.map(Self.normalizedPath)
        )
    }

    public init(approvedExecutableURLs: [URL]) {
        self.init(approvedExecutableURLs: Set(approvedExecutableURLs))
    }

    public func run(
        _ request: ProcessRequest
    ) async throws -> ProcessResult {
        let executablePath = try validate(request)
        let process = Process()
        let managedProcess = ManagedProcess(process)
        let standardOutputPipe = Pipe()
        let standardErrorPipe = Pipe()
        let termination = ProcessTermination()

        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = request.arguments
        process.currentDirectoryURL = request.workingDirectoryURL
        process.standardOutput = standardOutputPipe
        process.standardError = standardErrorPipe
        process.terminationHandler = { finishedProcess in
            let status = finishedProcess.terminationStatus
            Task {
                await termination.finish(status: status)
            }
        }

        let clock = ContinuousClock()
        let start = clock.now

        do {
            try process.run()
        } catch {
            throw ProcessExecutionError.couldNotStart(
                path: executablePath,
                reason: error.localizedDescription
            )
        }

        standardOutputPipe.fileHandleForWriting.closeFile()
        standardErrorPipe.fileHandleForWriting.closeFile()

        let standardOutputTask = Task.detached {
            standardOutputPipe.fileHandleForReading.readDataToEndOfFile()
        }
        let standardErrorTask = Task.detached {
            standardErrorPipe.fileHandleForReading.readDataToEndOfFile()
        }

        let status = try await waitForCompletion(
            of: managedProcess,
            termination: termination,
            timeout: request.timeout
        )
        let standardOutput = await standardOutputTask.value
        let standardError = await standardErrorTask.value
        let duration = start.duration(to: clock.now)

        try Task.checkCancellation()

        return ProcessResult(
            standardOutput: standardOutput,
            standardError: standardError,
            status: status,
            durationMilliseconds: milliseconds(in: duration)
        )
    }

    private func validate(
        _ request: ProcessRequest
    ) throws -> String {
        guard request.executableURL.isFileURL,
              request.executableURL.path.hasPrefix("/") else {
            throw ProcessExecutionError.executableURLMustBeAbsolute(
                request.executableURL.absoluteString
            )
        }
        guard request.timeout > .zero else {
            throw ProcessExecutionError.invalidTimeout
        }

        let executablePath = Self.normalizedPath(request.executableURL)
        guard approvedExecutablePaths.contains(executablePath) else {
            throw ProcessExecutionError.executableNotApproved(
                path: executablePath
            )
        }

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(
            atPath: executablePath,
            isDirectory: &isDirectory
        ), !isDirectory.boolValue else {
            throw ProcessExecutionError.executableNotFound(
                path: executablePath
            )
        }
        guard FileManager.default.isExecutableFile(
            atPath: executablePath
        ) else {
            throw ProcessExecutionError.executableNotRunnable(
                path: executablePath
            )
        }

        if let workingDirectoryURL = request.workingDirectoryURL {
            var workingDirectoryIsDirectory: ObjCBool = false
            guard workingDirectoryURL.isFileURL,
                  FileManager.default.fileExists(
                    atPath: workingDirectoryURL.path,
                    isDirectory: &workingDirectoryIsDirectory
                  ),
                  workingDirectoryIsDirectory.boolValue else {
                throw ProcessExecutionError.invalidWorkingDirectory(
                    path: workingDirectoryURL.path
                )
            }
        }

        return executablePath
    }

    private func waitForCompletion(
        of process: ManagedProcess,
        termination: ProcessTermination,
        timeout: Duration
    ) async throws -> ProcessStatus {
        try await withThrowingTaskGroup(
            of: Completion.self
        ) { group in
            group.addTask {
                .exited(code: await termination.wait())
            }
            group.addTask {
                try await Task.sleep(for: timeout)
                return .timedOut
            }

            do {
                guard let completion = try await group.next() else {
                    throw CancellationError()
                }

                switch completion {
                case .exited(let code):
                    group.cancelAll()
                    return .exited(code: code)
                case .timedOut:
                    await stop(
                        process,
                        termination: termination
                    )
                    group.cancelAll()
                    return .timedOut
                }
            } catch {
                await stop(
                    process,
                    termination: termination
                )
                group.cancelAll()
                throw error
            }
        }
    }

    private func stop(
        _ process: ManagedProcess,
        termination: ProcessTermination
    ) async {
        process.terminate()

        for _ in 0..<10 {
            guard process.isRunning else { break }
            try? await Task.sleep(for: .milliseconds(10))
        }

        if process.isRunning {
            process.forceTerminate()
        }

        _ = await termination.wait()
    }

    private func milliseconds(in duration: Duration) -> Int {
        let components = duration.components
        let milliseconds =
            components.seconds * 1_000
            + components.attoseconds / 1_000_000_000_000_000
        return max(0, Int(milliseconds))
    }

    private static func normalizedPath(_ url: URL) -> String {
        url.standardizedFileURL.resolvingSymlinksInPath().path
    }
}

private enum Completion: Sendable {
    case exited(code: Int32)
    case timedOut
}

private actor ProcessTermination {
    private var status: Int32?
    private var continuations: [CheckedContinuation<Int32, Never>] = []

    func wait() async -> Int32 {
        if let status {
            return status
        }

        return await withCheckedContinuation { continuation in
            continuations.append(continuation)
        }
    }

    func finish(status: Int32) {
        guard self.status == nil else { return }
        self.status = status

        for continuation in continuations {
            continuation.resume(returning: status)
        }
        continuations.removeAll()
    }
}

private final class ManagedProcess: @unchecked Sendable {
    private let lock = NSLock()
    private let process: Process

    init(_ process: Process) {
        self.process = process
    }

    var isRunning: Bool {
        lock.withLock {
            process.isRunning
        }
    }

    func terminate() {
        lock.withLock {
            if process.isRunning {
                process.terminate()
            }
        }
    }

    func forceTerminate() {
        lock.withLock {
            if process.isRunning {
                Darwin.kill(process.processIdentifier, SIGKILL)
            }
        }
    }
}
