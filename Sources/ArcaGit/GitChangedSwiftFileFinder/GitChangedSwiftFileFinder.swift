import Foundation

public struct GitChangedSwiftFileFinder: Sendable {
    public init() {}

    public func find(from path: String) throws -> [String] {
        let repositoryFinder = GitRepositoryFinder()
        let repositoryRoot = try repositoryFinder.discover(from: path)
        let statusOutput = try loadStatusOutput(repositoryRoot: repositoryRoot)
        return try parseStatusOutput(
            statusOutput,
            repositoryRoot: repositoryRoot
        )
    }

    private func loadStatusOutput(repositoryRoot: String) throws -> Data {
        let process = Process()
        let standardOutput = Pipe()
        let standardError = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = [
            "status",
            "--porcelain=v1",
            "-z",
            "--untracked-files=all"
        ]
        process.currentDirectoryURL = URL(
            fileURLWithPath: repositoryRoot,
            isDirectory: true
        )
        process.standardOutput = standardOutput
        process.standardError = standardError

        do {
            try process.run()
        } catch {
            throw GitChangedSwiftFileFinderError.commandCouldNotRun(
                repositoryRoot: repositoryRoot,
                reason: error.localizedDescription
            )
        }

        let output = standardOutput.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw GitChangedSwiftFileFinderError.commandFailed(
                repositoryRoot: repositoryRoot
            )
        }

        return output
    }

    private func parseStatusOutput(
        _ output: Data,
        repositoryRoot: String
    ) throws -> [String] {
        let fields = output.split(separator: 0, omittingEmptySubsequences: true)
        var fieldIndex = 0
        var selectedFiles = Set<String>()

        while fieldIndex < fields.count {
            let entry = fields[fieldIndex]
            fieldIndex += 1

            guard entry.count >= 4,
                  entry[entry.startIndex.advanced(by: 2)] == 0x20 else {
                throw GitChangedSwiftFileFinderError.invalidStatusOutput(
                    repositoryRoot: repositoryRoot
                )
            }

            let indexStatus = entry[entry.startIndex]
            let workingTreeStatus = entry[entry.startIndex.advanced(by: 1)]
            let hasOriginalPath = isRenameOrCopy(indexStatus)
                || isRenameOrCopy(workingTreeStatus)

            if hasOriginalPath {
                guard fieldIndex < fields.count else {
                    throw GitChangedSwiftFileFinderError.invalidStatusOutput(
                        repositoryRoot: repositoryRoot
                    )
                }
                fieldIndex += 1
            }

            guard indexStatus != statusDeleted,
                  workingTreeStatus != statusDeleted else {
                continue
            }

            let pathData = Data(entry.dropFirst(3))
            guard let relativePath = String(data: pathData, encoding: .utf8) else {
                throw GitChangedSwiftFileFinderError.invalidStatusOutput(
                    repositoryRoot: repositoryRoot
                )
            }

            let file = URL(fileURLWithPath: repositoryRoot, isDirectory: true)
                .appendingPathComponent(relativePath)
                .standardizedFileURL
                .resolvingSymlinksInPath()

            var isDirectory: ObjCBool = false
            guard file.pathExtension.lowercased() == "swift",
                  FileManager.default.fileExists(
                    atPath: file.path,
                    isDirectory: &isDirectory
                  ),
                  !isDirectory.boolValue else {
                continue
            }

            selectedFiles.insert(file.path)
        }

        return selectedFiles.sorted()
    }

    private func isRenameOrCopy(_ status: UInt8) -> Bool {
        status == statusRenamed || status == statusCopied
    }

    private var statusDeleted: UInt8 { Character("D").asciiValue! }
    private var statusRenamed: UInt8 { Character("R").asciiValue! }
    private var statusCopied: UInt8 { Character("C").asciiValue! }
}
