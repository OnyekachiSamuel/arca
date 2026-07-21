public enum ArcanExitStatus: Int32, Equatable, Sendable {
    case success = 0
    case findingsDetected = 1
    case invalidInput = 2
    case executionFailure = 3

    var outputDestination: CommandOutputDestination {
        switch self {
        case .success, .findingsDetected:
            .standardOutput
        case .invalidInput, .executionFailure:
            .standardError
        }
    }
}
