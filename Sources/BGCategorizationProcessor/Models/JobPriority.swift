import Foundation

public enum JobPriority: Int, Sendable, Codable, Comparable {
    case low = 0
    case normal = 1
    case high = 2

    public static func < (lhs: JobPriority, rhs: JobPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
