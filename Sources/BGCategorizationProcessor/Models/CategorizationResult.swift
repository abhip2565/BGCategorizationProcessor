import Foundation

public struct CategorizationResult: Sendable, Codable, Hashable {
    public let itemID: String
    public let categoryScores: [String: Double]
    public let topCategory: String?
    public let processedAt: Date

    public init(
        itemID: String,
        categoryScores: [String: Double],
        topCategory: String?,
        processedAt: Date = Date()
    ) {
        self.itemID = itemID
        self.categoryScores = categoryScores
        self.topCategory = topCategory
        self.processedAt = processedAt
    }
}
