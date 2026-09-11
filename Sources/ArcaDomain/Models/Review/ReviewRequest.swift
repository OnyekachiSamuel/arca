import Foundation

public struct ReviewRequest: Codable, Equatable, Sendable {
    public let id: UUID
    public let repositoryRoot: String?
    public let selectedFiles: [String]
    public let changes: [CodeChange]
    public let selectedReviewTypes: Set<ReviewType>
    public let configuration: ArcaConfiguration

    public init(
        id: UUID,
        repositoryRoot: String? = nil,
        selectedFiles: [String],
        changes: [CodeChange] = [],
        selectedReviewTypes: Set<ReviewType> = Set(ReviewType.allCases),
        configuration: ArcaConfiguration = .defaults
    ) {
        self.id = id
        self.repositoryRoot = repositoryRoot
        self.selectedFiles = selectedFiles
        self.changes = changes
        self.selectedReviewTypes = selectedReviewTypes
        self.configuration = configuration
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case repositoryRoot
        case selectedFiles
        case changes
        case selectedReviewTypes
        case configuration
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        repositoryRoot = try container.decodeIfPresent(
            String.self,
            forKey: .repositoryRoot
        )
        selectedFiles = try container.decode([String].self, forKey: .selectedFiles)
        changes = try container.decodeIfPresent(
            [CodeChange].self,
            forKey: .changes
        ) ?? []
        selectedReviewTypes = try container.decodeIfPresent(
            Set<ReviewType>.self,
            forKey: .selectedReviewTypes
        ) ?? Set(ReviewType.allCases)
        configuration = try container.decodeIfPresent(
            ArcaConfiguration.self,
            forKey: .configuration
        ) ?? .defaults
    }
}
