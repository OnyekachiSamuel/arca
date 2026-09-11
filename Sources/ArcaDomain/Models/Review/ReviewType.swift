import Foundation

public enum ReviewType: String, Codable, CaseIterable, Sendable {
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
    switch self {
    case .swift:
      "swift"
    case .swiftUI:
      "swiftui"
    case .tca:
      "tca"
    case .security:
      "security"
    case .godObject:
      "god-object"
    case .all:
      "all"
    }
  }

  public init?(commandLineName: String) {
    guard
      let reviewType = Self.allCases.first(where: {
        $0.commandLineName == commandLineName
      })
    else {
      return nil
    }
    self = reviewType
  }
}
