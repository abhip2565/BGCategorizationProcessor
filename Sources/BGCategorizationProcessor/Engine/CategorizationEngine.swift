import Foundation

public struct CategorizationEngine: Sendable {
    private let embeddingProvider: EmbeddingProvider
    private let config: ClassificationConfig

    public init(embeddingProvider: EmbeddingProvider, config: ClassificationConfig) {
        self.embeddingProvider = embeddingProvider
        self.config = config
    }

    func classify(
        text: String,
        itemID: String,
        centroids: [String: [Float]]
    ) async throws -> CategorizationResult {
        if centroids.isEmpty {
            return CategorizationResult(
                itemID: itemID,
                categoryScores: [:],
                topCategory: nil
            )
        }

        let truncated = String(text.prefix(config.maxTextLength)).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !truncated.isEmpty else {
            throw CategorizationError.textTooShort
        }

        let chunks = TextChunker.chunk(truncated, sentencesPerChunk: config.sentencesPerChunk)
        guard !chunks.isEmpty else {
            throw CategorizationError.textTooShort
        }

        var totals: [String: Double] = Dictionary(
            uniqueKeysWithValues: centroids.keys.map { ($0, 0) }
        )

        for chunk in chunks {
            let embedding = try await embeddingProvider.embed(chunk)
            for (categoryID, centroid) in centroids {
                guard embedding.count == centroid.count else {
                    throw CategorizationError.modelLoadFailed(
                        reason: "Embedding dimension mismatch for category \(categoryID)"
                    )
                }
                totals[categoryID, default: 0] += cosineSimilarity(embedding, centroid)
            }
        }

        let divisor = Double(chunks.count)
        let averagedScores = totals.mapValues { $0 / divisor }
        let maxScore = averagedScores.values.max() ?? 0
        let topCandidates = averagedScores.filter { $0.value == maxScore }

        let topCategory: String?
        if topCandidates.count == 1, maxScore >= config.minimumConfidence {
            topCategory = topCandidates.first?.key
        } else {
            topCategory = nil
        }

        return CategorizationResult(
            itemID: itemID,
            categoryScores: averagedScores,
            topCategory: topCategory
        )
    }
}
