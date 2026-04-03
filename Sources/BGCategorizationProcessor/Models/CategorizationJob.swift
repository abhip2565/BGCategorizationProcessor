import Foundation

public struct CategorizationJob: Sendable, Codable, Hashable {
    public let itemID: String
    public let text: String
    public let priority: JobPriority
    public let enqueuedAt: Date
    public let retryCount: Int

    public init(
        itemID: String,
        text: String,
        priority: JobPriority,
        enqueuedAt: Date = Date(),
        retryCount: Int = 0
    ) {
        self.itemID = itemID
        self.text = text
        self.priority = priority
        self.enqueuedAt = enqueuedAt
        self.retryCount = retryCount
    }
}
