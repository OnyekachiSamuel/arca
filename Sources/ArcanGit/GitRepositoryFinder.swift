import Foundation

public struct GitRepositoryFinder: Sendable {
    public init() {}

    public func discover(from path: String) throws -> String {
        let process = Process()
        let standardOutput = Pipe()
        let standardError = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["rev-parse", "--show-toplevel"]
        process.currentDirectoryURL = URL(fileURLWithPath: path, isDirectory: true)
        process.standardOutput = standardOutput
        process.standardError = standardError

        do {
            try process.run()
        } catch {
            throw GitRepositoryFinderError.commandCouldNotRun(
                path: path,
                reason: error.localizedDescription
            )
        }

        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw GitRepositoryFinderError.notRepository(path: path)
        }

        let outputData = standardOutput.fileHandleForReading.readDataToEndOfFile()
        let output = String(decoding: outputData, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !output.isEmpty else {
            throw GitRepositoryFinderError.invalidOutput(path: path)
        }

        return URL(fileURLWithPath: output)
            .standardizedFileURL
            .resolvingSymlinksInPath()
            .path
    }
}
