import Foundation

public enum ReviewType: String, Codable, CaseIterable, Sendable {
    case godObject
    case tcaArchitecture
    case style
    case teamConvention

    public var commandLineName: String {
        switch self {
        case .godObject:
            "god-object"
        case .tcaArchitecture:
            "tca-architecture"
        case .style:
            "style"
        case .teamConvention:
            "team-convention"
        }
    }

    public init?(commandLineName: String) {
        guard let reviewType = Self.allCases.first(where: {
            $0.commandLineName == commandLineName
        }) else {
            return nil
        }
        self = reviewType
    }
}
