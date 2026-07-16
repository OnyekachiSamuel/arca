import Foundation

public struct ReviewRequest: Codable, Equatable, Sendable {
    public let id: UUID
    public let selectedFiles: [String]
    public let changes: [CodeChange]

    public init(
        id: UUID,
        selectedFiles: [String],
        changes: [CodeChange] = []
    ) {
        self.id = id
        self.selectedFiles = selectedFiles
        self.changes = changes
    }
}
