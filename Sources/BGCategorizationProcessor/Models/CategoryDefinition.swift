import Foundation

public struct CategoryDefinition: Sendable, Codable, Hashable {
    public let id: String
    public let label: String
    public let descriptors: [String]

    public init(id: String, label: String, descriptors: [String]) {
        self.id = id
        self.label = label
        self.descriptors = descriptors
    }
}
