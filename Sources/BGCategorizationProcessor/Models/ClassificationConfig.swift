import Foundation

public struct ClassificationConfig: Sendable, Codable, Hashable {
    public let minimumConfidence: Double
    public let sentencesPerChunk: Int
    public let maxTextLength: Int

    public init(
        minimumConfidence: Double = 0.30,
        sentencesPerChunk: Int = 5,
        maxTextLength: Int = 50_000
    ) {
        self.minimumConfidence = minimumConfidence
        self.sentencesPerChunk = max(1, sentencesPerChunk)
        self.maxTextLength = max(1, maxTextLength)
    }
}
