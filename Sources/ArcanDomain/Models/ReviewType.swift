import Foundation

public enum ReviewType: String, Codable, CaseIterable, Sendable {
    case godObject
    case tcaArchitecture
    case style
    case teamConvention
    case generalLLM
}
