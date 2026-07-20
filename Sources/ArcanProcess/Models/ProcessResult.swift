import Foundation

public struct ProcessResult: Equatable, Sendable {
    public let standardOutput: Data
    public let standardError: Data
    public let status: ProcessStatus
    public let durationMilliseconds: Int

    public init(
        standardOutput: Data,
        standardError: Data,
        status: ProcessStatus,
        durationMilliseconds: Int
    ) {
        self.standardOutput = standardOutput
        self.standardError = standardError
        self.status = status
        self.durationMilliseconds = durationMilliseconds
    }
}
