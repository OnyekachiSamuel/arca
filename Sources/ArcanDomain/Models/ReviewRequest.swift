import Foundation

public struct ReviewRequest: Codable, Equatable, Sendable {
    public let id: UUID
    public let selectedFiles: [String]

    public init(id: UUID, selectedFiles: [String]) {
        self.id = id
        self.selectedFiles = selectedFiles
    }
}
