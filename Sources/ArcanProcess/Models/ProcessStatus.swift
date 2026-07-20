public enum ProcessStatus: Equatable, Sendable {
    case exited(code: Int32)
    case timedOut
}
