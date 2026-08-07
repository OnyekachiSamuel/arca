import Foundation

public struct SwiftLintExecutableLocator: Sendable {
    private let environment: [String: String]

    public init(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        self.environment = environment
    }

    public func locate() -> SwiftLintAvailability {
        if let configuredPath = environment[
            "ARCA_SWIFTLINT_EXECUTABLE"
        ] {
            return configuredAvailability(at: configuredPath)
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
                return .available(executable)
            }
        }

        return .unavailable(.executableNotFound)
    }

    private func configuredAvailability(
        at path: String
    ) -> SwiftLintAvailability {
        let url = URL(fileURLWithPath: path).standardizedFileURL
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(
            atPath: url.path,
            isDirectory: &isDirectory
        ), !isDirectory.boolValue else {
            return .unavailable(.configuredExecutableNotFound(path))
        }
        guard FileManager.default.isExecutableFile(atPath: url.path) else {
            return .unavailable(.configuredExecutableNotRunnable(path))
        }
        return .available(url)
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
