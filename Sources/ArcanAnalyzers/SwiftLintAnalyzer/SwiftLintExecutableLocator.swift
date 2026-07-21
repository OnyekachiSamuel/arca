import Foundation

public struct SwiftLintExecutableLocator: Sendable {
    private let environment: [String: String]

    public init(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        self.environment = environment
    }

    public func locate() -> URL? {
        if let configuredPath = environment[
            "ARCAN_SWIFTLINT_EXECUTABLE"
        ], let executable = executableURL(at: configuredPath) {
            return executable
        }

        let searchDirectories = (environment["PATH"] ?? "")
            .split(separator: ":", omittingEmptySubsequences: true)
            .map(String.init)
        let commonDirectories = [
            "/opt/homebrew/bin",
            "/usr/local/bin"
        ]

        for directory in searchDirectories + commonDirectories {
            let candidate = URL(
                fileURLWithPath: directory,
                isDirectory: true
            ).appendingPathComponent("swiftlint")
            if let executable = executableURL(at: candidate.path) {
                return executable
            }
        }

        return nil
    }

    private func executableURL(at path: String) -> URL? {
        let url = URL(fileURLWithPath: path).standardizedFileURL
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(
            atPath: url.path,
            isDirectory: &isDirectory
        ), !isDirectory.boolValue,
        FileManager.default.isExecutableFile(atPath: url.path) else {
            return nil
        }
        return url
    }
}
