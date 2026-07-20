import Foundation

public struct ProcessRequest: Equatable, Sendable {
    public let executableURL: URL
    public let arguments: [String]
    public let workingDirectoryURL: URL?
    public let timeout: Duration

    public init(
        executableURL: URL,
        arguments: [String],
        workingDirectoryURL: URL? = nil,
        timeout: Duration
    ) {
        self.executableURL = executableURL
        self.arguments = arguments
        self.workingDirectoryURL = workingDirectoryURL
        self.timeout = timeout
    }
}
