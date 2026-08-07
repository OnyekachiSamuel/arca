import ArcaDomain
import Foundation

public struct GitDiffProvider: Sendable {
    public init() {}

    public func extract(from path: String) throws -> [CodeChange] {
        let gitRepositoryFinder = GitRepositoryFinder()
        let repositoryRoot = try gitRepositoryFinder.discover(from: path)
        let changedFiles = try GitChangedSwiftFileFinder()
            .find(from: repositoryRoot)
        let repositoryHasHead = try hasHead(repositoryRoot: repositoryRoot)
        let trackedChanges = repositoryHasHead
            ? try loadTrackedChanges(repositoryRoot: repositoryRoot)
            : [:]

        return try changedFiles.compactMap { filePath in
            let trackedChange = trackedChanges[filePath]
            let patch = try loadPatch(
                filePath: filePath,
                trackedChange: trackedChange,
                repositoryHasHead: repositoryHasHead,
                repositoryRoot: repositoryRoot
            )
            return try parsePatch(
                patch,
                filePath: filePath,
                previousFilePath: trackedChange?.previousFilePath,
                repositoryRoot: repositoryRoot
            )
        }
    }

    private func hasHead(repositoryRoot: String) throws -> Bool {
        let result = try runGit(
            arguments: ["rev-parse", "--verify", "--quiet", "HEAD"],
            repositoryRoot: repositoryRoot
        )
        return result.terminationStatus == 0
    }

    private func loadTrackedChanges(
        repositoryRoot: String
    ) throws -> [String: TrackedChange] {
        let result = try runGit(
            arguments: [
                "diff",
                "--name-status",
                "-z",
                "--find-renames",
                "HEAD"
            ],
            repositoryRoot: repositoryRoot
        )
        guard result.terminationStatus == 0 else {
            throw GitDiffProviderError.commandFailed(
                repositoryRoot: repositoryRoot
            )
        }

        let fields = result.standardOutput.split(
            separator: 0,
            omittingEmptySubsequences: true
        )
        var fieldIndex = 0
        var changes: [String: TrackedChange] = [:]

        while fieldIndex < fields.count {
            guard let status = decode(fields[fieldIndex]) else {
                throw GitDiffProviderError.invalidOutput(
                    repositoryRoot: repositoryRoot
                )
            }
            fieldIndex += 1

            if status.hasPrefix("R") || status.hasPrefix("C") {
                guard fieldIndex + 1 < fields.count,
                      let oldPath = decode(fields[fieldIndex]),
                      let newPath = decode(fields[fieldIndex + 1]) else {
                    throw GitDiffProviderError.invalidOutput(
                        repositoryRoot: repositoryRoot
                    )
                }
                fieldIndex += 2

                let currentFilePath = absolutePath(
                    newPath,
                    repositoryRoot: repositoryRoot
                )
                changes[currentFilePath] = TrackedChange(
                    relativeFilePath: newPath,
                    previousRelativeFilePath: oldPath,
                    previousFilePath: absolutePath(
                        oldPath,
                        repositoryRoot: repositoryRoot
                    )
                )
            } else {
                guard fieldIndex < fields.count,
                      let currentPath = decode(fields[fieldIndex]) else {
                    throw GitDiffProviderError.invalidOutput(
                        repositoryRoot: repositoryRoot
                    )
                }
                fieldIndex += 1

                let currentFilePath = absolutePath(
                    currentPath,
                    repositoryRoot: repositoryRoot
                )
                changes[currentFilePath] = TrackedChange(
                    relativeFilePath: currentPath,
                    previousRelativeFilePath: nil,
                    previousFilePath: nil
                )
            }
        }

        return changes
    }

    private func loadPatch(
        filePath: String,
        trackedChange: TrackedChange?,
        repositoryHasHead: Bool,
        repositoryRoot: String
    ) throws -> String {
        let result: GitCommandResult

        if repositoryHasHead, let trackedChange {
            var arguments = patchArguments
            arguments.append("HEAD")
            arguments.append("--")
            if let previousPath = trackedChange.previousRelativeFilePath {
                arguments.append(previousPath)
            }
            arguments.append(trackedChange.relativeFilePath)
            result = try runGit(
                arguments: arguments,
                repositoryRoot: repositoryRoot
            )

            guard result.terminationStatus == 0 else {
                throw GitDiffProviderError.commandFailed(
                    repositoryRoot: repositoryRoot
                )
            }
        } else {
            var arguments = patchArguments
            arguments.append(contentsOf: [
                "--no-index",
                "--",
                "/dev/null",
                filePath
            ])
            result = try runGit(
                arguments: arguments,
                repositoryRoot: repositoryRoot
            )

            guard result.terminationStatus == 0
                    || result.terminationStatus == 1 else {
                throw GitDiffProviderError.commandFailed(
                    repositoryRoot: repositoryRoot
                )
            }
        }

        guard let patch = String(data: result.standardOutput, encoding: .utf8) else {
            throw GitDiffProviderError.invalidOutput(
                repositoryRoot: repositoryRoot
            )
        }
        return patch
    }

    private func parsePatch(
        _ patch: String,
        filePath: String,
        previousFilePath: String?,
        repositoryRoot: String
    ) throws -> CodeChange? {
        guard !isBinaryPatch(patch) else {
            return nil
        }

        var addedLineRanges: [ChangedLineRange] = []
        var modifiedLineRanges: [ChangedLineRange] = []
        var deletedLineRanges: [DeletedLineRange] = []

        for line in patch.split(separator: "\n", omittingEmptySubsequences: false) {
            guard line.hasPrefix("@@ ") else { continue }
            let components = line.split(
                separator: " ",
                maxSplits: 3,
                omittingEmptySubsequences: true
            )
            guard components.count == 4,
                  components[0] == "@@",
                  components[3].hasPrefix("@@"),
                  let oldRange = parseHunkRange(components[1], prefix: "-"),
                  let newRange = parseHunkRange(components[2], prefix: "+") else {
                throw GitDiffProviderError.invalidOutput(
                    repositoryRoot: repositoryRoot
                )
            }

            if oldRange.count == 0, newRange.count > 0 {
                addedLineRanges.append(ChangedLineRange(
                    startLine: newRange.start,
                    endLine: newRange.start + newRange.count - 1
                ))
            } else if oldRange.count > 0, newRange.count == 0 {
                deletedLineRanges.append(DeletedLineRange(
                    originalStartLine: oldRange.start,
                    originalEndLine: oldRange.start + oldRange.count - 1
                ))
            } else if oldRange.count > 0, newRange.count > 0 {
                modifiedLineRanges.append(ChangedLineRange(
                    startLine: newRange.start,
                    endLine: newRange.start + newRange.count - 1
                ))
            }
        }

        return CodeChange(
            filePath: filePath,
            previousFilePath: previousFilePath,
            addedLineRanges: addedLineRanges,
            modifiedLineRanges: modifiedLineRanges,
            deletedLineRanges: deletedLineRanges
        )
    }

    private func isBinaryPatch(_ patch: String) -> Bool {
        patch.split(separator: "\n").contains { line in
            line.hasPrefix("Binary files ") || line == "GIT binary patch"
        }
    }

    private func parseHunkRange(
        _ token: Substring,
        prefix: Character
    ) -> (start: Int, count: Int)? {
        guard token.first == prefix else { return nil }
        let values = token.dropFirst().split(
            separator: ",",
            maxSplits: 1,
            omittingEmptySubsequences: false
        )
        guard let startValue = values.first,
              let start = Int(startValue) else {
            return nil
        }
        let count = values.count == 2 ? Int(values[1]) : 1
        guard let count, start >= 0, count >= 0 else { return nil }
        return (start, count)
    }

    private func runGit(
        arguments: [String],
        repositoryRoot: String
    ) throws -> GitCommandResult {
        let process = Process()
        let standardOutput = Pipe()
        var environment = ProcessInfo.processInfo.environment
        environment["LC_ALL"] = "C"

        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = arguments
        process.currentDirectoryURL = URL(
            fileURLWithPath: repositoryRoot,
            isDirectory: true
        )
        process.environment = environment
        process.standardOutput = standardOutput
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            throw GitDiffProviderError.commandCouldNotRun(
                repositoryRoot: repositoryRoot,
                reason: error.localizedDescription
            )
        }

        let output = standardOutput.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return GitCommandResult(
            standardOutput: output,
            terminationStatus: process.terminationStatus
        )
    }

    private func decode(_ data: Data.SubSequence) -> String? {
        String(data: Data(data), encoding: .utf8)
    }

    private func absolutePath(
        _ relativePath: String,
        repositoryRoot: String
    ) -> String {
        URL(fileURLWithPath: repositoryRoot, isDirectory: true)
            .appendingPathComponent(relativePath)
            .standardizedFileURL
            .resolvingSymlinksInPath()
            .path
    }

    private var patchArguments: [String] {
        [
            "diff",
            "--unified=0",
            "--no-color",
            "--no-ext-diff",
            "--no-textconv",
            "--find-renames"
        ]
    }
}

private struct TrackedChange: Sendable {
    let relativeFilePath: String
    let previousRelativeFilePath: String?
    let previousFilePath: String?
}

private struct GitCommandResult: Sendable {
    let standardOutput: Data
    let terminationStatus: Int32
}
