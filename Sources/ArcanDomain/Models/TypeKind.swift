import Foundation

public enum TypeKind: String, Codable, Equatable, Sendable {
    case `class`
    case `struct`
    case  actor
    case `extension`
}
