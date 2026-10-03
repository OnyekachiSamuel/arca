import Foundation

public enum ReviewType: String, Codable, Sendable {
    case swift
    case swiftUI = "swiftui"
    case tca
    case security
    case godObject = "god-object"
    case all
    
    public static let analysisTypes: [Self] = [
        .swift, .swiftUI, .tca, .security, .godObject,
    ]
    
    public var commandLineName: String {
        rawValue
    }
    
    public init?(commandLineName: String) {
        self.init(rawValue: commandLineName)
    }
}
